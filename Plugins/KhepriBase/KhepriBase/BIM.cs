using System;
using System.Collections.Generic;

namespace KhepriBase {

    public class BIMLevel {
        public static Dictionary<double, BIMLevel> levels = new Dictionary<double, BIMLevel>();

        public double elevation;

        public static BIMLevel FindLevelAtElevation(double elevation) {
            BIMLevel level;
            return levels.TryGetValue(elevation, out level) ? level : null;
        }

        public static BIMLevel CreateLevelAtElevation(double elevation) {
            BIMLevel level = new BIMLevel { elevation = elevation };
            levels.Add(elevation, level);
            return level;
        }

        public static BIMLevel FindOrCreateLevelAtElevation(double elevation) =>
            FindLevelAtElevation(elevation) ?? CreateLevelAtElevation(elevation);
    }

    public class BIMFamily { }

    public class SlabFamily : BIMFamily {
        public double totalThickness;
        public double coatingThickness;
    }

    public class FloorFamily : SlabFamily { }

    public class RoofFamily : SlabFamily { }

    public class WallFamily : BIMFamily {
        public double thickness;
    }

    // Some families (e.g., for tables, chairs, doors, etc) have a pre-defined 3D object associated

    public class BIMObjectFamily : BIMFamily {

    }

    public class TableFamily : BIMObjectFamily {
        public double length;
        public double width;
        public double height;
        public double top_thickness;
        public double leg_thickness;

        static Dictionary<Tuple<double, double, double, double, double>, TableFamily> familyInstances =
            new Dictionary<Tuple<double, double, double, double, double>, TableFamily>();

        public static TableFamily FindOrCreate(double length, double width, double height, double top_thickness, double leg_thickness) {
            var tuple = Tuple.Create(length, width, height, top_thickness, leg_thickness);
            TableFamily family = null;
            if (!familyInstances.TryGetValue(tuple, out family)) {
                family = new TableFamily { length = length, width = width, height = height, top_thickness = top_thickness, leg_thickness = leg_thickness };
                familyInstances.Add(tuple, family);
            }
            return family;
        }
    }

    public class ChairFamily : BIMObjectFamily {
        public double length;
        public double width;
        public double height;
        public double seat_height;
        public double thickness;

        static Dictionary<Tuple<double, double, double, double, double>, ChairFamily> familyInstances =
            new Dictionary<Tuple<double, double, double, double, double>, ChairFamily>();

        public static ChairFamily FindOrCreate(double length, double width, double height, double seat_height, double thickness) {
            var tuple = Tuple.Create(length, width, height, seat_height, thickness);
            ChairFamily family = null;
            if (!familyInstances.TryGetValue(tuple, out family)) {
                family = new ChairFamily { length = length, width = width, height = height, seat_height = seat_height, thickness = thickness };
                familyInstances.Add(tuple, family);
            }
            return family;
        }
    }

    public class TableChairFamily : BIMObjectFamily {
        public TableFamily tableFamily;
        public ChairFamily chairFamily;
        public int chairsOnTop;
        public int chairsOnBottom;
        public int chairsOnRight;
        public int chairsOnLeft;
        public double spacing;

        static Dictionary<Tuple<TableFamily, ChairFamily, int, int, int, int, double>, TableChairFamily> familyInstances =
            new Dictionary<Tuple<TableFamily, ChairFamily, int, int, int, int, double>, TableChairFamily>();

        public static TableChairFamily FindOrCreate(TableFamily tableFamily, ChairFamily chairFamily,
            int chairsOnTop, int chairsOnBottom, int chairsOnRight, int chairsOnLeft, double spacing) {
            var tuple = Tuple.Create(tableFamily, chairFamily, chairsOnTop, chairsOnBottom, chairsOnRight, chairsOnLeft, spacing);
            TableChairFamily family = null;
            if (!familyInstances.TryGetValue(tuple, out family)) {
                family = new TableChairFamily {
                    tableFamily = tableFamily, chairFamily = chairFamily,
                    chairsOnTop = chairsOnTop, chairsOnBottom = chairsOnBottom,
                    chairsOnRight = chairsOnRight, chairsOnLeft = chairsOnLeft,
                    spacing = spacing
                };
                familyInstances.Add(tuple, family);
            }
            return family;
        }
    }
}
