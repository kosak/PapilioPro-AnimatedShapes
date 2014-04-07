LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use std.textio.all;
use work.util.coord_t;
use work.util.kCoordWidth;
use work.util.pixel_t;
use work.util.point_t;
use work.util.point_t_vector;
 
ENTITY tb_PointArraysToScanSequence IS
END tb_PointArraysToScanSequence;
 
ARCHITECTURE behavior OF tb_PointArraysToScanSequence IS
  constant clk_period : time := 10 ns;
  constant numComponents: positive := 2;
  constant kScreenHeight: positive:= 4;
  constant kScreenWidth: positive:= 5;
  
  type expectedPoint_t is
  record
    y: natural;
    x: natural;
  end record;

  --Inputs
  signal clk: std_logic := '0';
  signal start: std_logic := '0';
  signal ready: std_logic;
  signal trigger: std_logic;
  signal pixel: pixel_t;
  
  signal slaveFirsts: point_t_vector(0 to numComponents-1);
  signal slaveLasts: point_t_vector(0 to numComponents-1);
  signal slaveStarts: std_logic_vector(0 to numComponents-1);
  signal slaveReadys: std_logic_vector(0 to numComponents-1);
  signal slaveMoveNexts: std_logic_vector(0 to numComponents-1);
  signal slavePoints: point_t_vector(0 to numComponents-1);
  signal slaveDones: std_logic_vector(0 to numComponents-1);

  -- Two crossing diagonal lines: (0,0)-(2,2) and (2,0)-(0,2)  
  constant expected_0_0_2_2_0_2_2_0: std_logic_vector :=
    "10100" &
    "01000" &
    "10100" &
    "00000";
    
  -- A horizontal line intersecting a slanted line: (0,0)-(3,4) and (1,0)-(1,4).
  constant expected_0_0_3_4_1_0_1_4: std_logic_vector :=
    "10000" &
    "11111" &
    "00110" &
    "00001";


BEGIN
  generate_lines: for i in 0 to numComponents-1 generate
    lineX: entity work.ArbitraryLine(Behavioral)
      port map (
        clk => clk,
        first => slaveFirsts(i),
        last => slaveLasts(i),
        start => slaveStarts(i),
        ready => slaveReadys(i),
        moveNext => slaveMoveNexts(i),
        point => slavePoints(i),
        done => slaveDones(i)
      );
  end generate generate_lines;
  
  uut: entity work.PointArraysToScanSequence(Behavioral)
    generic map (numComponents => numComponents,
      kScreenHeight => kScreenHeight,
      kScreenWidth => kScreenWidth
    )
    port map (
      clk => clk,
      start => start,
      ready => ready,
      trigger => trigger,
      pixel => pixel,
      slaveStarts => slaveStarts,
      slaveReadys => slaveReadys,
      slaveMoveNexts => slaveMoveNexts,
      slavePoints => slavePoints,
      slaveDones => slaveDones
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
        first0: expectedPoint_t; last0: expectedPoint_t;
        first1: expectedPoint_t; last1: expectedPoint_t;
        expectedResults: std_logic_vector) is
      variable text: line;
    begin
      report "Testing two lines: " &
          ToString(first0) & "-" & ToString(last0) &
          " and " &
          ToString(first1) & "-" & ToString(last1);
        
      slaveFirsts(0) <= ToPoint(first0);
      slaveLasts(0) <= ToPoint(last0);
      slaveFirsts(1) <= ToPoint(first1);
      slaveLasts(1) <= ToPoint(last1);

      start <= '1';
      wait for clk_period;
      start <= '0';
      trigger <= '0';
      
      while (ready = '0') loop
        wait for clk_period;
      end loop;
      for i in 0 to numComponents-1 loop
        slaveFirsts(i) <= (y => (others => 'U'), x => (others => 'U'));
        slaveLasts(i) <= (y => (others => 'U'), x => (others => 'U'));
      end loop;
      
      trigger <= '1';
      wait for clk_period;
      trigger <= 'U';
      for i in expectedResults'low to expectedResults'high loop
        write(text, "index " & natural'image(i)
          & ": expected " & std_logic'image(expectedResults(i))
          & "; got " & std_logic'image(pixel));
        assert (pixel = expectedResults(i)) report text.all;
        -- writeline(output, text);
        deallocate(text);
        wait for clk_period;
      end loop;
      
    end procedure test;
      
  begin
    wait for clk_period*10;
    -- two components in a 3x3 grid
    --   component 0 draws a line from (0,0) to (2,2)
    --   component 1 draws a line from (0,2) to (2,0)
    --   Result is:
    --   X X
    --    X
    --   X X
    test((0, 0), (2, 2),
         (0, 2), (2, 0),
         expected_0_0_2_2_0_2_2_0);

    test((0, 0), (3, 4),
         (1, 0), (1, 4),
         expected_0_0_3_4_1_0_1_4);
    wait;
  end process;

END;
