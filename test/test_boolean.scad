use <common.scad>

// Boolean operations "difference" and "intersection" with multiple colors have other results than shown in the "F5" preview, so they are best avoided.
// The behavior is of course explainable: each color is rendered independently (with all other colors removed), and the final results are unioned together.
layout(scale=3) {
    v = 3/8 * [1, 1, 1];

    // Union works normal, although the resulting model has overlapping colors
    union() {
        color("red") translate(-v) tetra();
        color("green") tetra();
        color("blue") translate(v) tetra();
    }

    // One full red tetra results:
    // - for color red, a tetra minus two empty volumes is a tetra
    // - for other colors, an empty volume minus something else is empty
    difference() {
        color("red") translate(-v) tetra();
        color("green") tetra();
        color("blue") translate(v) tetra();
    }

    // The result is empty: there are always two empty volumes, and intersection with an empty volume is empty
    intersection() {
        color("red") translate(-v) tetra();
        color("green") tetra();
        color("blue") translate(v) tetra();
    }
}
