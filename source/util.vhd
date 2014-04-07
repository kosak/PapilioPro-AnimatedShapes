library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.numeric_std.ALL;
use std.textio.all;

 
package util is
  constant kCoordWidth: positive := 10;  -- 10 bits is enough for 640x480

  subtype coord_t is unsigned(kCoordWidth-1 downto 0);
  
  -- Support for a "point" type.  
  type point_t is
  record
    y: coord_t;
    x: coord_t;
  end record;
  type point_t_vector is array(natural range<>) of point_t;
  
  function CreatePoint(y: natural; x: natural) return point_t;
  function ToString(point: point_t) return string;
  
  -- Support for a "rectangle" type.
  type rect_t is record
    origin: point_t;
    size: point_t;
  end record rect_t;
  type rect_t_vector is array(natural range<>) of rect_t;

  function CreateRectangle(y0: natural; x0: natural; height: natural; width: natural)
      return rect_t;

  -- Support for an 8-bit color pixel (3 bits of resolution for red, 3 for green, 2 for blue).
  type vgaColor_t is record
    r: unsigned(2 downto 0);
    g: unsigned(2 downto 0);
    b: unsigned(1 downto 0);
  end record;
  type vgaColor_t_vector is array(natural range<>) of vgaColor_t;

  function CreateVgaColor(r: natural; g: natural; b: natural) return vgaColor_t;
  function ToString(color: vgaColor_t) return string;
  
end util;
 
package body util is
  function CreatePoint(y: natural; x: natural) return point_t is
  begin
    return (
      y => to_unsigned(y, point_t.y'length),
      x => to_unsigned(x, point_t.x'length));
  end function CreatePoint;
  
  function ToString(point: point_t) return string is
    variable text: line;
  begin
    write(text, "(" &
        integer'image(to_integer(point.y)) & "," &
        integer'image(to_integer(point.x)) & ")");
    return text.all;
  end function ToString;

  function CreateVgaColor(r: natural; g: natural; b: natural) return vgaColor_t is
  begin
    return (
        r => to_unsigned(r, vgaColor_t.r'length),
        g => to_unsigned(g, vgaColor_t.g'length),
        b => to_unsigned(b, vgaColor_t.b'length));
  end function CreateVgaColor;
  
  function ToString(color: vgaColor_t) return string is
    variable text: line;
  begin
    write(text, "(" &
        integer'image(to_integer(color.r)) & "," &
        integer'image(to_integer(color.g)) & "," &
        integer'image(to_integer(color.b)) & ")");
    return text.all;
  end function ToString;

  function CreateRectangle(y0: natural; x0: natural; height: natural; width: natural)
      return rect_t is
  begin
    return (
      origin => (
        y => to_unsigned(y0, point_t.y'length),
        x => to_unsigned(x0, point_t.x'length)),
      size => (
        y => to_unsigned(height, point_t.y'length),
        x => to_unsigned(width, point_t.x'length)));
  end function CreateRectangle;

end util;
