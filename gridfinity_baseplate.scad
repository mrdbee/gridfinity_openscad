// include instead of use, so we get the pitch
include <gridfinity_modules.scad>

// X dimension in grid units (halves are allowed, e.g. 4.5)
xsize = 5;
// Y dimension in grid units (halves are allowed, e.g. 7.5)
ysize = 3;
weighted = false;
lid = false;
// Which end a partial (half-unit) column sits at
partial_column = "right";  // [ "right", "left" ]
// Which end a partial (half-unit) row sits at
partial_row = "back";  // [ "back", "front" ]

near_x = partial_column == "left";
near_y = partial_row == "front";

if (lid) {
  base_lid(xsize, ysize, near_x=near_x, near_y=near_y);
}
else if (weighted) {
  weighted_baseplate(xsize, ysize, near_x=near_x, near_y=near_y);
}
else {
  frame_plain(xsize, ysize, near_x=near_x, near_y=near_y);
}


module base_lid(num_x, num_y, near_x=false, near_y=false) {
  magnet_od = 6.5;
  magnet_position = min(gridfinity_pitch/2-8, gridfinity_pitch/2-4-magnet_od/2);
  magnet_thickness = 2.4;
  eps = 0.1;
  
  // these used the globals rather than the module's own arguments
  translate([0, 0, 7]) frame_plain(num_x, num_y, trim=0.25, near_x=near_x, near_y=near_y);
  difference() {
    grid_block(num_x, num_y, 1, magnet_diameter=0, screw_depth=0, near_x=near_x, near_y=near_y);
    gridcopy_cells(full_cells(num_x, near_x), full_cells(num_y, near_y)) {
      cornercopy(magnet_position) {
        translate([0, 0, 7-magnet_thickness])
        cylinder(d=magnet_od, h=magnet_thickness+eps, $fn=48);
      }
    }
  }
}


module weighted_baseplate(num_x, num_y, near_x=false, near_y=false) {
  magnet_od = 6.5;
  magnet_position = min(gridfinity_pitch/2-8, gridfinity_pitch/2-4-magnet_od/2);
  magnet_thickness = 2.4;
  eps = 0.1;
  
  difference() {
    frame_plain(num_x, num_y, 6.4, near_x=near_x, near_y=near_y);
    
    // a partial cell is half a unit across and has no room for the weight
    // pocket or the magnet pair, so it is left solid
    gridcopy_cells(full_cells(num_x, near_x), full_cells(num_y, near_y)) {
      cornercopy(magnet_position) {
        translate([0, 0, -magnet_thickness])
        cylinder(d=magnet_od, h=magnet_thickness+eps, $fn=48);
        
        translate([0, 0, -6.4]) cylinder(d=3.5, h=6.4, $fn=24);
        
        // counter-sunk holes in the bottom
        translate([0, 0, -6.41]) cylinder(d1=8.5, d2=3.5, h=2.5, $fn=24);
      }
      
      translate([-10.7, -10.7, -6.41]) cube([21.4, 21.4, 4.01]);
      
      for (a2=[0,90]) rotate([0, 0, a2])
      hull() for (a=[0, 180]) rotate([0, 0, a])
      translate([-14.9519, 0, -6.41]) cylinder(d=8.5, h=2.01, $fn=24);
    }
  }
}


module frame_plain(num_x, num_y, extra_down=0, trim=0, near_x=false, near_y=false) {
  ht = extra_down > 0 ? 4.4 : 5;
  corner_radius = 3.75;
  corner_position = gridfinity_pitch/2-corner_radius-trim;
  difference() {
    hull() cornercopy(corner_position, num_x, num_y) 
    translate([0, 0, -extra_down]) cylinder(r=corner_radius, h=ht+extra_down, $fn=44);
    translate([0, 0, trim ? 0 : -0.01]) 
    render() gridcopy_partial(num_x, num_y, 1, near_x, near_y) pad_oversize(margins=1);
  }
}