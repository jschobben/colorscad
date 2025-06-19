module layout(scale) {
    for (i = [0:$children-1]) {
        translate([i*scale, 0, 0]) children(i);
    }
}

scale(10) {
    layout(2) {
        color("red") cube();
        color([0, 1, 0]) cube();
        color("#0000ff") cube();
    }

    steps = 4;
    translate([0, 5, 0]) for (r = [0:steps], g = [0:steps], b = [0:steps]) {
        translate([r,g,b]*2) color([r, g, b]/steps) cube();
    }
}
