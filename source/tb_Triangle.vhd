LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use std.textio.all;
use work.util.coord_t;
use work.util.kCoordWidth;
use work.util.point_t;
use work.util.point_t_vector;
use work.util.vgaColor_t;
 
ENTITY tb_Triangle IS
END tb_Triangle;
 
ARCHITECTURE behavior OF tb_Triangle IS
  constant clk_period : time := 10 ns;
  constant kScreenHeight: positive:= 6;
  constant kScreenWidth: positive:= 11;
  
  type expectedPoint_t is
  record
    y: natural;
    x: natural;
  end record;

  signal clk: std_logic := '0';
  signal vertices: point_t_vector(0 to 2);
  signal fgColor: vgaColor_t;
  signal start: std_logic := '0';
  signal ready: std_logic;
  signal pixelActive: std_logic;
  signal pixelColor: vgaColor_t;
  signal moveNext: std_logic;
  
  -- Two crossing diagonal lines: (0,0)-(2,2) and (2,0)-(0,2)  
  constant expected: std_logic_vector :=
    "00000100000" &
    "00001010000" &
    "00010001000" &
    "00100000100" &
    "01000000010" &
    "11111111111";

BEGIN
  uut: entity work.Triangle(Behavioral)
    generic map (
      kScreenHeight => kScreenHeight,
      kScreenWidth => kScreenWidth
    )
    port map (
      clk => clk,
      vertices => vertices,
      fgColor => fgColor,
      start => start,
      ready => ready,
      pixelActive => pixelActive,
      pixelColor => pixelColor,
      moveNext => moveNext
    );
      
  clk <= not clk after clk_period/2;

  stim_proc: process
    function ToPoint(ep: expectedPoint_t) return point_t is
    begin
      return (
        y => to_unsigned(ep.y, kCoordWidth),
        x => to_unsigned(ep.x, coord_t'length));
    end function ToPoint;
    
    function ToString(ep: expectedPoint_t) return string is
    begin
      return "(" & natural'image(ep.y) & "," & natural'image(ep.x) & ")";
    end function ToString;
    
    procedure test(
        r: natural;
        g: natural;
        b: natural;
        v0: expectedPoint_t;
        v1: expectedPoint_t;
        v2: expectedPoint_t;
        expectedResults: std_logic_vector) is
      variable text: line;
    begin
      report "Testing triangle: " &
          ToString(v0) & ";" & ToString(v1) & ";" & ToString(v2);
      fgColor.r <= to_unsigned(r, fgColor.r'length);
      fgColor.g <= to_unsigned(g, fgColor.g'length);
      fgColor.b <= to_unsigned(b, fgColor.b'length);
      vertices(0) <= ToPoint(v0);
      vertices(1) <= ToPoint(v1);
      vertices(2) <= ToPoint(v2);
      start <= '1';
      wait for clk_period;
      start <= '0';
      moveNext <= '0';
      
      while (ready = '0') loop
        wait for clk_period;
      end loop;

      for i in expectedResults'low to expectedResults'high loop
        write(text, "index " & natural'image(i)
          & ": expected " & std_logic'image(expectedResults(i))
          & "; got " & std_logic'image(pixelActive));
        write(text, ". Expected (" &
          natural'image(r) & "," & natural'image(g) & "," & natural'image(b) & "), got (" &
          natural'image(to_integer(pixelColor.r)) & "," &
          natural'image(to_integer(pixelColor.g)) & "," &
          natural'image(to_integer(pixelColor.b)) & ")");
        assert (pixelActive = expectedResults(i) and
            pixelColor.r = to_unsigned(r, pixelColor.r'length) and
            pixelColor.g = to_unsigned(g, pixelColor.g'length) and
            pixelColor.b = to_unsigned(b, pixelColor.b'length)) report text.all;
        -- writeline(output, text);
        deallocate(text);
        moveNext <= '1';
        wait for clk_period;
      end loop;
      moveNext <= '0';
      report "Triangle done";
    end procedure test;
      
  begin
    wait for clk_period*10;
    test(1, 2, 3, (0, 5), (5, 10), (5, 0), expected);
    wait;
  end process;

END;
