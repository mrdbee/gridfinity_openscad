gridfinity_pitch = 42;
gridfinity_zpitch = 7;
gridfinity_clearance = 0.5;  // each bin is undersize by this much

// set this to produce sharp corners on baseplates and bins
// not for general use (breaks compatibility) but may be useful for special cases
sharp_corners = 0;


// basic block with cutout in top to be stackable, optional holes in bottom
// start with this and begin 'carving'
module grid_block(num_x=1, num_y=1, num_z=2, magnet_diameter=6.5, screw_depth=6, center=false, hole_overhang_remedy=false, half_pitch=false, box_corner_attachments_only = false, near_x=false, near_y=false) {
  corner_radius = 3.75;
  outer_size = gridfinity_pitch - gridfinity_clearance;  // typically 41.5
  block_corner_position = outer_size/2 - corner_radius;  // need not match center of pad corners
  magnet_thickness = 2.4;
  magnet_position = min(gridfinity_pitch/2-8, gridfinity_pitch/2-4-magnet_diameter/2);
  screw_hole_diam = 3;
  gp = gridfinity_pitch;
  
  suppress_holes = num_x < 1 || num_y < 1;
  
  // Attachments sit on the full-unit lattice, which shifts when a partial
  // row/column is placed at the near end. A partial cell is skipped: it is
  // half a unit across, and the pair of holes spans more than that.
  hole_cells_x = [ for (c = partial_cells(num_x, 1, near_x)) if (c[1] >= 1 - 0.0001) c ];
  hole_cells_y = [ for (c = partial_cells(num_y, 1, near_y)) if (c[1] >= 1 - 0.0001) c ];
  
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
        pad_grid(num_x, num_y, half_pitch, near_x, near_y);
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
      gridcopycorners(hole_cells_x, hole_cells_y, magnet_position, box_corner_attachments_only)
      translate([0, 0, -0.1]) cylinder(d=screw_hole_diam, h=esd+0.1, $fn=28);
    }
    
    if (emd > 0) {  // add pockets for magnets if requested
      gridcopycorners(hole_cells_x, hole_cells_y, magnet_position, box_corner_attachments_only)
      translate([0, 0, -0.1]) cylinder(d=emd, h=magnet_thickness+0.1, $fn=41);
    }
    
    if (overhang_fix) {  // people seem to really like this overhang fix
      gridcopycorners(hole_cells_x, hole_cells_y, magnet_position, box_corner_attachments_only)
      translate([0, 0, magnet_thickness-0.1]) 
      render() intersection() {  // for some reason OpenSCAD blows up if I don't render here
        translate([-emd/2, -screw_hole_diam/2, 0]) cube([emd, screw_hole_diam, overhang_fix_depth+0.1]);
        cylinder(d=emd, h=1, $fn=41);
      }
    }
  }
}


// Divide an axis of `num` grid units into cells of at most `step` units,
// returning [low edge, size] per cell in grid units. One cell may be partial;
// `near` puts it at the low end of the axis instead of the high end, which is
// what lets a half-unit bin line up with a baseplate whose half row is at the
// near edge.
function partial_cells(num, step=1, near=false) =
  let (eps  = 0.0001,
       n    = ceil(num/step - eps),
       frac = num - (n-1)*step)
  near
    ? [ for (i=[0:n-1]) i == 0 ? [0, frac] : [frac + (i-1)*step, step] ]
    : [ for (i=[0:n-1]) [i*step, i == n-1 ? frac : step] ];


// Copy children into every cell of a grid that may contain a partial row/column.
// Children must be one cell's geometry, `step` grid units square, anchored with
// its lower-left corner at (-gridfinity_pitch/2, -gridfinity_pitch/2).
// A partial cell is trimmed by intersecting with a shifted copy of the same
// geometry, so the cut edge is rounded over the way a full cell is rather than
// being sliced off square.
module gridcopy_partial(num_x, num_y, step=1, near_x=false, near_y=false) {
  eps = 0.0001;
  cells_x = partial_cells(num_x, step, near_x);
  cells_y = partial_cells(num_y, step, near_y);

  for (cx = cells_x) for (cy = cells_y) {
    cut_far_x = cx[1] < step - eps;
    cut_far_y = cy[1] < step - eps;

    translate([gridfinity_pitch*cx[0], gridfinity_pitch*cy[0], 0])
    intersection() {
      children();
      if (cut_far_x) {
        translate([gridfinity_pitch*(cx[1]-step), 0, 0]) children();
      }
      if (cut_far_y) {
        translate([0, gridfinity_pitch*(cy[1]-step), 0]) children();
      }
      if (cut_far_x && cut_far_y) {
        // without this the far corner would be rectangular
        translate([gridfinity_pitch*(cx[1]-step), gridfinity_pitch*(cy[1]-step), 0]) children();
      }
    }
  }
}


module pad_grid(num_x, num_y, half_pitch=false, near_x=false, near_y=false) {
  step = half_pitch ? 0.5 : 1;
  gridcopy_partial(num_x, num_y, step, near_x, near_y) pad_cell(step);
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

// similar to cornercopy, can only copy to box corners.
// cells_x/cells_y are [low edge, size] lists as returned by partial_cells, so
// the copies follow the cell lattice even when it is shifted by a partial cell.
module gridcopycorners(cells_x, cells_y, r, onlyBoxCorners = false) {
  nx = len(cells_x);
  ny = len(cells_y);
  if (nx > 0 && ny > 0) {
    for (xi=[0:nx-1]) for (yi=[0:ny-1]) 
      for (xx=[-1, 1]) for (yy=[-1, 1]) 
        if(!onlyBoxCorners || 
          (xi == 0 && yi == 0 && xx == -1 && yy == -1) ||
          (xi == nx-1 && yi == ny-1 && xx == 1 && yy == 1) ||
          (xi == 0 && yi == ny-1 && xx == -1 && yy == 1) ||
          (xi == nx-1 && yi == 0 && xx == 1 && yy == -1))  
          translate([gridfinity_pitch*cells_x[xi][0], gridfinity_pitch*cells_y[yi][0], 0]) 
          translate([xx*r, yy*r, 0]) children();
  }
}

// similar to quadtranslate but expands to extremities of a block
module cornercopy(r, num_x=1, num_y=1) {
  for (xx=[-r, gridfinity_pitch*(num_x-1)+r]) for (yy=[-r, gridfinity_pitch*(num_y-1)+r]) 
    translate([xx, yy, 0]) children();
}


// copy children to each listed cell, without trimming anything.
// cells are [low edge, size] entries as returned by partial_cells.
module gridcopy_cells(cells_x, cells_y) {
  for (cx = cells_x) for (cy = cells_y)
    translate([gridfinity_pitch*cx[0], gridfinity_pitch*cy[0], 0]) children();
}


// the full-unit cells of an axis, skipping a partial one
function full_cells(num, near=false) =
  [ for (c = partial_cells(num, 1, near)) if (c[1] >= 1 - 0.0001) c ];


// make repeated copies of something(s) at the gridfinity spacing of 42mm
module gridcopy(num_x, num_y) {
  for (xi=[1:num_x]) for (yi=[1:num_y]) translate([gridfinity_pitch*(xi-1), gridfinity_pitch*(yi-1), 0]) children();
}


