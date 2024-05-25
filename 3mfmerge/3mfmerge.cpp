#include <algorithm>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <map>
#include <sstream>

#include <lib3mf_implicit.hpp>


float linearToSRGB(float linear)
{
  if (linear <= 0.0031308) {
    return linear * 12.92f;
  }
  const float a = 0.055f;
  return static_cast<float>((1.0 + a) * std::pow(linear, 1/2.4) - a);
}

// Rotate indices (reorder) such that the smallest one is at index 0, preserving relative order
void rotate_indices(Lib3MF::sTriangle& triangle)
{
  auto& idx = triangle.m_Indices;
  if ((idx[1] < idx[0]) && (idx[1] < idx[2])) {
    Lib3MF_uint32 t = idx[0];
    idx[0] = idx[1];
    idx[1] = idx[2];
    idx[2] = t;
  } else if ((idx[2] < idx[0]) && (idx[2] < idx[1])) {
    Lib3MF_uint32 t = idx[2];
    idx[2] = idx[1];
    idx[1] = idx[0];
    idx[0] = t;
  }
}

std::string replace_all(std::string s, const std::string& key, const std::string& replacement)
{
  size_t pos = s.find(key);
  while (pos != std::string::npos) {
    s.replace(pos, key.size(), replacement);
    pos = s.find(key, pos + replacement.size());
  }
  return s;
}

// Returns number of skipped input lines
int mergeModels(char* outputFile)
{
  int skipped = 0;
  Lib3MF::PWrapper wrapper = Lib3MF::CWrapper::loadLibrary();
  Lib3MF::PModel mergedModel = wrapper->CreateModel();
  Lib3MF::PComponentsObject mergedComponentsObject = mergedModel->AddComponentsObject();
  std::map<Lib3MF_uint32, std::string> id_to_name;  // Stores name for each component ID in the merged model
  for (std::string line; std::getline(std::cin, line);) {
    // Define new color, extracted from filename such as "[0, 0.25, 1, 1].3mf"
    Lib3MF_uint32 colorGroupID = -1;
    size_t col_start = line.find("[");
    size_t col_end = line.find("]");
    std::string component_name;
    if ((col_start == std::string::npos) || (col_end == std::string::npos)) {
      std::cerr << "Not coloring '" << line << "': filename doesn't contain proper square brackets" << std::endl;
    } else {
      std::string col = line.substr(col_start + 1, col_end - (col_start + 1));

      // Determine the component's name.
      // This name needs to be stored in multiple places to be picked up by the majority of programs.
      // TODO also allow setting a custom name directly from OpenSCAD code
      component_name = "[" + col + "]";

      std::vector<float> cols;
      size_t prev = 0;
      while (true) {
        size_t pos = col.find(",", prev);
        std::string val = col.substr(prev, pos - prev);
        cols.push_back(std::stof(val));
        if (pos == std::string::npos) break;
        prev = pos + 1;
      }
      if (cols.size() != 4) {
        std::cerr << "Not coloring '" << line << "': filename doesn't mention exactly 4 RGBA values" << std::endl;
      } else {
        Lib3MF_single r = linearToSRGB(cols[0]);
        Lib3MF_single g = linearToSRGB(cols[1]);
        Lib3MF_single b = linearToSRGB(cols[2]);
        Lib3MF_single a = cols[3];
        Lib3MF::PColorGroup colorGroup = mergedModel->AddColorGroup();
        Lib3MF::sColor color = wrapper->FloatRGBAToColor(r, g, b, a);
        colorGroup->AddColor(color);
        colorGroupID = colorGroup->GetResourceID();
      }
    }

    try {
      // Load model
      Lib3MF::PModel model = wrapper->CreateModel();
      Lib3MF::PReader reader = model->QueryReader("3mf");
      reader->ReadFromFile(line);

      // Loop over its objects
      Lib3MF::PObjectIterator objectIterator = model->GetObjects();
      while (objectIterator->MoveNext()) {
        const Lib3MF::PObject& object = objectIterator->GetCurrentObject();
        if (object->IsMeshObject()) {
          Lib3MF::PMeshObject mesh = model->GetMeshObjectByID(object->GetResourceID());

          // Get the mesh
          std::vector<Lib3MF::sPosition> vertices;
          std::vector<Lib3MF::sTriangle> triangle_indices;
          mesh->GetVertices(vertices);
          mesh->GetTriangleIndices(triangle_indices);

          // Rotate triangle indices, and sort the triangle list
          // This is to have consistent output, useful for testing purposes
          for (auto& triangle : triangle_indices) {
            rotate_indices(triangle);
          }
          std::sort(triangle_indices.begin(), triangle_indices.end(),
            [](Lib3MF::sTriangle a, Lib3MF::sTriangle b) {
              auto& ai = a.m_Indices;
              auto& bi = b.m_Indices;
              if (ai[0] != bi[0]) {
                return ai[0] < bi[0];
              }
              if (ai[1] != bi[1]) {
                return ai[1] < bi[1];
              }
              return ai[2] < bi[2];
            }
          );

          // Add the mesh
          Lib3MF::PMeshObject newMesh = mergedModel->AddMeshObject();
          newMesh->SetGeometry(vertices, triangle_indices);

          // Set color
          if (colorGroupID != -1) { // If we managed to extract a color from the filename
            newMesh->SetObjectLevelProperty(colorGroupID, 1);
          }

          // This component name assignment works for Cura, PrusaSlicer, SuperSlicer
          newMesh->SetName(component_name);

          // Add to merged model
          Lib3MF::PComponent component = mergedComponentsObject->AddComponent(newMesh.get(), wrapper->GetIdentityTransform());

          // Store component's ID->name mapping for later
          Lib3MF_uint32 id = component->GetObjectResourceID();
          id_to_name.emplace(id, component_name);
        } else if (object->IsComponentsObject()) {
          std::cout << line << ": skipping component object #" << object->GetResourceID() << std::endl;
        } else {
          std::cout << line << ": skipping unknown object #" << object->GetResourceID() << std::endl;
        }
      }
    } catch (Lib3MF::ELib3MFException &e) {
      std::cerr << "Trouble while processing '" << line << "': " << e.what() << std::endl;
      std::cerr << "Will skip this file/color, and proceed anyway." << std::endl;
      skipped++;
    }
  }
  Lib3MF::PBuildItem buildItem = mergedModel->AddBuildItem(mergedComponentsObject.get(), wrapper->GetIdentityTransform());

  // Add metadata attachment defining the component names; this works for Bambu Studio, OrcaSlicer
  Lib3MF::PAttachment attachment = mergedModel->AddAttachment("Metadata/model_settings.config", "");
  std::stringstream model_settings_stream;
  model_settings_stream
      << "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" << std::endl
      << "<config>" << std::endl
      << "  <object id=\"" << buildItem->GetObjectResourceID() << "\">" << std::endl;
  for (const auto& pair : id_to_name) {
    std::string component_name = replace_all(pair.second, "&", "&amp;");
    component_name = replace_all(std::move(component_name), "\"", "&quot;");
    model_settings_stream
        << "    <part id=\"" << pair.first << "\" subtype=\"normal_part\">" << std::endl
        << "      <metadata key=\"name\" value=\"" << component_name << "\"/>" << std::endl
        << "    </part>" << std::endl;
  }
  model_settings_stream
      << "  </object>" << std::endl
      << "</config>" << std::endl;
  std::string model_settings = std::move(model_settings_stream.str());
  attachment->ReadFromBuffer(Lib3MF::CInputVector<Lib3MF_uint8>(
      reinterpret_cast<const Lib3MF_uint8*>(model_settings.data()), model_settings.size()
  ));

  Lib3MF::PWriter writer = mergedModel->QueryWriter("3mf");
  writer->WriteToFile(outputFile);
  return skipped;
}

int main(int argc, char** argv)
{
  if (argc != 2) {
    std::cerr << "Usage: " << argv[0] << " OUTPUT_FILE" << std::endl
              << "A list of filenames is read from stdin; these must be .3mf files." << std::endl
              << "After loading each file, its mesh gets assigned a color based on the filename; and finally, all the" << std::endl
              << "meshes are merged into one model, which is saved as OUTPUT_FILE." << std::endl
              << "OUTPUT_FILE must not yet exist." << std::endl
              << "Example input line (filename): '[1, 0, 0.5, 0.9].3mf'." << std::endl
              << "This would result in a color assignment of r=1, g=0, b=0.5, alpha=0.9." << std::endl;
    return 1;
  }
  try {
    int skipped = mergeModels(argv[1]);
    if (skipped > 0) {
      std::cerr << "Warning: " << skipped << " input files were skipped!" << std::endl;
      return 1;
    }
  } catch (Lib3MF::ELib3MFException &e) {
    std::cerr << e.what() << std::endl;
    return e.getErrorCode();
  }
  return 0;
}
