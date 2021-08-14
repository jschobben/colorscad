use <common.scad>

// Export to ascii STL, with coordinates rounded to a multiple of 1/64:
// openscad spikes.scad -o - --export-format asciistl | perl -MPOSIX -pe 's/(\d+\.\d+)/POSIX::round($1 \/ 2**-6) * 2**-6/ge' > spikes.stl

for (x = [[-2, -2, -2], [-2, 2, 2], [2, -2, 2], [2, 2, -2]]) hull() {
    rotate([90, 0, 0]) translate([-0.5, -0.5, -0.5]) tetra();
    translate(x) translate([-0.5, -0.5, -0.5]) tetra();
}
