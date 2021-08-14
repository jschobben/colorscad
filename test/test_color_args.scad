use <common.scad>

// Verify that all forms of color/alpha specification work.

layout(rows=4) {
    color("red") tetra();
    color("red", 0.75) tetra();
    color(alpha=0.5, "red") tetra();
    color(alpha=0.25, c="red") tetra();

    color([0, 1, 0]) tetra();
    color([0, 1, 0], 0.75) tetra();
    color([0, 1, 0, 0.5]) tetra();
    color([0, 1, 0, 0.5], alpha=0.25) tetra();

    /* These ones don't work in 2015.03, they can be added when support is dropped.
    color("#0000ff") tetra();
    color("#00f", 0.75) tetra();
    color("#0000ff80") tetra();
    color("#00f8", 0.25) tetra();
    */
}
