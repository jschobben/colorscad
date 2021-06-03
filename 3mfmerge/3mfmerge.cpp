#include <iostream>
#include <lib3mf_implicit.hpp>


// Returns number of skipped input lines
int mergeModels(char* outputFile)
{
  int skipped = 0;
  Lib3MF::PWrapper wrapper = Lib3MF::CWrapper::loadLibrary();
  Lib3MF::PModel mergedModel = wrapper->CreateModel();
  Lib3MF::PComponentsObject mergedComponentsObject = mergedModel->AddComponentsObject();
  for (std::string line; std::getline(std::cin, line);) {
    // Define new color, extracted from filename such as "[0, 0.25, 1, 1].3mf"
    Lib3MF_uint32 colorGroupID = -1;
    size_t col_start = line.find("[");
    size_t col_end = line.find("]");
    if ((col_start == std::string::npos) || (col_end == std::string::npos)) {
      std::cerr << "Not coloring '" << line << "': filename doesn't contain proper square brackets" << std::endl;
    } else {
      std::string col = line.substr(col_start + 1, col_end - (col_start + 1));
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
        Lib3MF_single r = cols[0];
        Lib3MF_single g = cols[1];
        Lib3MF_single b = cols[2];
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

          // Copy the mesh
          std::vector<Lib3MF::sPosition> vertices;
          std::vector<Lib3MF::sTriangle> indices;
          mesh->GetVertices(vertices);
          mesh->GetTriangleIndices(indices);
          Lib3MF::PMeshObject newMesh = mergedModel->AddMeshObject();
          newMesh->SetGeometry(vertices, indices);

          // Set color
          if (colorGroupID != -1) { // If we managed to extract a color from the filename
            newMesh->SetObjectLevelProperty(colorGroupID, 1);
          }

          // Add to merged model
          mergedComponentsObject->AddComponent(newMesh.get(), wrapper->GetIdentityTransform());
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
  mergedModel->AddBuildItem(mergedComponentsObject.get(), wrapper->GetIdentityTransform());
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
