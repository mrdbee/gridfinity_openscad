gridfinity_pitch = 42;
gridfinity_zpitch = 7;
gridfinity_clearance = 0.5;  // each bin is undersize by this much

// set this to produce sharp corners on baseplates and bins
// not for general use (breaks compatibility) but may be useful for special cases
sharp_corners = 0;


// basic block with cutout in top to be stackable, optional holes in bottom
// start with this and begin 'carving'
module grid_block(num_x=1, num_y=1, num_z=2, magnet_diameter=6.5, screw_depth=6, center=false, hole_overhang_remedy=false, half_pitch=false, box_corner_attachments_only = false) {
  corner_radius = 3.75;
  outer_size = gridfinity_pitch - gridfinity_clearance;  // typically 41.5
  block_corner_position = outer_size/2 - corner_radius;  // need not match center of pad corners
  magnet_thickness = 2.4;
  magnet_position = min(gridfinity_pitch/2-8, gridfinity_pitch/2-4-magnet_diameter/2);
  screw_hole_diam = 3;
  gp = gridfinity_pitch;
  
  suppress_holes = num_x < 1 || num_y < 1;
  
  emd = suppress_holes ? 0 : magnet_diameter; // effective magnet diameter after override
  esd = suppress_holes ? 0 : screw_depth;     // effective screw depth after override
  
  overhang_fix = hole_overhang_remedy && emd > 0 && esd > 0;
  overhang_fix_depth = 0.3;  // assume this is enough
  
  totalht=gridfinity_zpitch*num_z+3.75;
  translate( center ? [-(num_x-1)*gridfinity_pitch/2, -(num_y-1)*gridfinity_pitch/2, 0] : [0, 0, 0] )
  difference() {
    intersection() {
      union() {
        // logic for constructing odd-size grids of possibly half-pitch pads
        pad_grid(num_x, num_y, half_pitch);
        // main body will be cut down afterward
        translate([-gridfinity_pitch/2, -gridfinity_pitch/2, 5]) 
        cube([gridfinity_pitch*num_x, gridfinity_pitch*num_y, totalht-5]);
      }
      
      // crop with outer cylinders
      translate([0, 0, -0.1])
      hull() 
      cornercopy(block_corner_position, num_x, num_y) 
      cylinder(r=corner_radius, h=totalht+0.2, $fn=32);
    }
    
    // remove top so XxY can fit on top
      color("blue") 
      translate([0, 0, gridfinity_zpitch*num_z]) 
      pad_oversize(num_x, num_y, 1);
    
    if (esd > 0) {  // add pockets for screws if requested
      gridcopycorners(ceil(num_x), ceil(num_y), magnet_position, box_corner_attachments_only)
      translate([0, 0, -0.1]) cylinder(d=screw_hole_diam, h=esd+0.1, $fn=28);
    }
    
    if (emd > 0) {  // add pockets for magnets if requested
      gridcopycorners(ceil(num_x), ceil(num_y), magnet_position, box_corner_attachments_only)
      translate([0, 0, -0.1]) cylinder(d=emd, h=magnet_thickness+0.1, $fn=41);
    }
    
    if (overhang_fix) {  // people seem to really like this overhang fix
      gridcopycorners(ceil(num_x), ceil(num_y), magnet_position, box_corner_attachments_only)
      translate([0, 0, magnet_thickness-0.1]) 
      render() intersection() {  // for some reason OpenSCAD blows up if I don't render here
        translate([-emd/2, -screw_hole_diam/2, 0]) cube([emd, screw_hole_diam, overhang_fix_depth+0.1]);
        cylinder(d=emd, h=1, $fn=41);
      }
    }
  }
}


// Copy children into every cell of a grid whose last row/column may be partial.
// Children must be one cell's geometry, `step` grid units square, anchored with
// its lower-left corner at (-gridfinity_pitch/2, -gridfinity_pitch/2).
// A partial final row/column is trimmed by intersecting with a shifted copy of
// the same geometry, so the cut edge is rounded over the way a full cell is
// rather than being sliced off square.
module gridcopy_partial(num_x, num_y, step=1) {
  eps = 0.0001;  // tolerance so that e.g. 1.5 units at step 0.5 counts as exact
  nx = ceil(num_x/step - eps);
  ny = ceil(num_y/step - eps);
  // size of the final cell along each axis, in grid units (== step if it is full)
  frac_x = num_x - (nx-1)*step;
  frac_y = num_y - (ny-1)*step;

  for (xi=[1:nx]) for (yi=[1:ny]) {
    cut_far_x = xi == nx && frac_x < step - eps;
    cut_far_y = yi == ny && frac_y < step - eps;

    translate([gridfinity_pitch*step*(xi-1), gridfinity_pitch*step*(yi-1), 0])
    intersection() {
      children();
      if (cut_far_x) {
        translate([gridfinity_pitch*(frac_x-step), 0, 0]) children();
      }
      if (cut_far_y) {
        translate([0, gridfinity_pitch*(frac_y-step), 0]) children();
      }
      if (cut_far_x && cut_far_y) {
        // without this the far corner would be rectangular
        translate([gridfinity_pitch*(frac_x-step), gridfinity_pitch*(frac_y-step), 0]) children();
      }
    }
  }
}


module pad_grid(num_x, num_y, half_pitch=false) {
  step = half_pitch ? 0.5 : 1;
  gridcopy_partial(num_x, num_y, step) pad_cell(step);
}


// One base pad, `step` grid units square. A full-size pad is centred on the
// origin; a half-pitch pad is the lower-left quadrant of one, so both are
// anchored at (-gridfinity_pitch/2, -gridfinity_pitch/2) and tile the same way.
module pad_cell(step=1) {
  if (step >= 1) {
    pad_oversize();
  }
  else {
    render()  // render here to keep tree from blowing up
    intersection() {
      pad_oversize();
      translate([-gridfinity_pitch/2, 0, 0]) pad_oversize();
      translate([0, -gridfinity_pitch/2, 0]) pad_oversize();
      translate([-gridfinity_pitch/2, -gridfinity_pitch/2, 0]) pad_oversize();
    }
  }
}


// one full-size cell's worth of half-pitch pads
module pad_halfsize() {
  for (xi=[0:1]) for (yi=[0:1]) 
  translate([xi*gridfinity_pitch/2, yi*gridfinity_pitch/2, 0]) 
  pad_cell(0.5);
}

// like a cylinder but produces a square solid instead of a round one
// specified 'diameter' is the side length of the square, not the diagonal diameter
module cylsq(d, h) {
  translate([-d/2, -d/2, 0]) cube([d, d, h]);
}

// like a tapered cylinder with two diameters, but square instead of round
module cylsq2(d1, d2, h) {
  linear_extrude(height=h, scale=d2/d1)
  square([d1, d1], center=true);
}

// unit pad slightly oversize at the top to be trimmed or joined with other feet or the rest of the model
// also useful as cutouts for stacking
module pad_oversize(num_x=1, num_y=1, margins=0) {
  pad_corner_position = gridfinity_pitch/2 - 4; // must be 17 to be compatible
  bevel1_top = 0.8;     // z of top of bottom-most bevel (bottom of bevel is at z=0)
  bevel2_bottom = 2.6;  // z of bottom of second bevel
  bevel2_top = 5;       // z of top of second bevel
  bonus_ht = 0.2;       // extra height (and radius) on second bevel
  
  // female parts are a bit oversize for a nicer fit
  radialgap = margins ? 0.25 : 0;  // oversize cylinders for a bit of clearance
  axialdown = margins ? 0.1 : 0;   // a tiny bit of axial clearance present in Zack's design
  
  translate([0, 0, -axialdown])
  difference() {
    union() {
      hull() cornercopy(pad_corner_position, num_x, num_y) {
        if (sharp_corners) {
          cylsq(d=1.6+2*radialgap, h=0.1);
          translate([0, 0, bevel1_top]) cylsq(d=3.2+2*radialgap, h=1.9);
        }
        else {
          cylinder(d=1.6+2*radialgap, h=0.1, $fn=24);
          translate([0, 0, bevel1_top]) cylinder(d=3.2+2*radialgap, h=1.9, $fn=32);
        }
      }
      
      hull() cornercopy(pad_corner_position, num_x, num_y) {
        if (sharp_corners) {
          translate([0, 0, bevel2_bottom]) 
          cylsq2(d1=3.2+2*radialgap, d2=7.5+0.5+2*radialgap+2*bonus_ht, h=bevel2_top-bevel2_bottom+bonus_ht);
        }
        else {
          translate([0, 0, bevel2_bottom]) 
          cylinder(d1=3.2+2*radialgap, d2=7.5+0.5+2*radialgap+2*bonus_ht, h=bevel2_top-bevel2_bottom+bonus_ht, $fn=32);
        }
      }
    }
    
    // cut off bottom if we're going to go negative
    if (margins) {
      translate([-gridfinity_pitch/2, -gridfinity_pitch/2, 0])
      cube([gridfinity_pitch*num_x, gridfinity_pitch*num_y, axialdown]);
    }
  }
}

// similar to cornercopy, can only copy to box corners
module gridcopycorners(num_x, num_y, r, onlyBoxCorners = false) {
  for (xi=[1:num_x]) for (yi=[1:num_y]) 
    for (xx=[-1, 1]) for (yy=[-1, 1]) 
      if(!onlyBoxCorners || 
        (xi == 1 && yi == 1 && xx == -1 && yy == -1) ||
        (xi == num_x && yi == num_y && xx == 1 && yy == 1) ||
        (xi == 1 && yi == num_y && xx == -1 && yy == 1) ||
        (xi == num_x && yi == 1 && xx == 1 && yy == -1))  
        translate([gridfinity_pitch*(xi-1), gridfinity_pitch*(yi-1), 0]) 
        translate([xx*r, yy*r, 0]) children();
}

// similar to quadtranslate but expands to extremities of a block
module cornercopy(r, num_x=1, num_y=1) {
  for (xx=[-r, gridfinity_pitch*(num_x-1)+r]) for (yy=[-r, gridfinity_pitch*(num_y-1)+r]) 
    translate([xx, yy, 0]) children();
}


// make repeated copies of something(s) at the gridfinity spacing of 42mm
module gridcopy(num_x, num_y) {
  for (xi=[1:num_x]) for (yi=[1:num_y]) translate([gridfinity_pitch*(xi-1), gridfinity_pitch*(yi-1), 0]) children();
}


