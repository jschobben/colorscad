module layout(rows=1, scale=2) {
    for (child = [0:$children-1]) {
        x = floor(child / rows);
        y = child % rows;
        translate([x*scale, y*scale, 0]) children(child);
    }
}

// Avoid non-triangular faces (i.e. squares on a cube).
// Those can be triangulated in multiple ways, which makes
// comparison against a reference object harder.
module tetra() {
    polyhedron(
        [[0, 0, 0], [0, 1, 1], [1, 0, 1], [1, 1, 0]],
        [[0, 1, 2], [0, 2, 3], [0, 3, 1], [1, 3, 2]]
    );
}

tetra();
