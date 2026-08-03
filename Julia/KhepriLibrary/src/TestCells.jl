export test_cell

test_cell(p=u0(), l=8, d=6, h=3, t=0.03, w2wr=0.9;
        location=p, length=l, depth=d, height=h,
        wall_thickness=t, slab_thickness=t, roof_thickness=t,
        window_to_wall_ratio=w2wr) =
  let path = rectangular_path(location, length, depth),
      w2wr1 = (1-window_to_wall_ratio)/2
    with_slab_family(thickness=slab_thickness) do
      slab(path)
    end
    with_wall_family(thickness=wall_thickness) do
      with_window_family(width=window_to_wall_ratio*length, height=window_to_wall_ratio*height) do
        w = wall(path, top_level=height)
        add_window(w, add_xy(location, length*w2wr1, height*w2wr1))
      end
    end
    with_roof_family(thickness=roof_thickness) do
      roof(path, level=h)
    end
  end
