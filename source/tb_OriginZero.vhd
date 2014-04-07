library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

ENTITY tb_OriginZero IS
END tb_OriginZero;
use work.util.kCoordWidth;
use work.util.coord_t;
use work.util.moveNextQueue_t;
use work.util.point_t;
use work.util.xposAndSegmentWidth_t;

ARCHITECTURE behavior OF tb_OriginZero IS
  constant clk_period : time := 10 ns;
  
  type widthAndBump_t is record
    segmentWidth: integer;
    shouldBumpX: std_logic;
  end record;
  type widthAndBump_t_vector is array(natural range<>) of widthAndBump_t;

  --Inputs
  signal clk : std_logic := '0';
  
  signal yDelta: coord_t;
  signal xDelta: coord_t;
  signal start: std_logic;
  signal ready: std_logic;
    
  signal moveNext: std_logic;
  signal xpos: coord_t;
  signal segmentWidth: coord_t;
  signal shouldBumpX: std_logic;
  signal done: std_logic;

  -- 0 degrees: origin to (0,11) => (width=12, bump = '1')
  constant expected_0_11: widthAndBump_t_vector := (0 => (12, '1'));

  -- shallow: slightly down and further to the right
  -- origin to (3, 11) => four segments where the widths are [2 4 4 2] and the bumps are 1.
  constant expected_3_11: widthAndBump_t_vector := ((2, '1'), (4, '1'), (4, '1'), (2, '1'));

  -- 45 degrees down and to the right:
  -- origin to (11,11) => 12 segments of width 1
  constant expected_11_11: widthAndBump_t_vector := (
    (1, '1'),
    (1, '1'),
    (1, '1'),
    (1, '1'),
    (1, '1'),
    (1, '1'),
    (1, '1'),
    (1, '1'),
    (1, '1'),
    (1, '1'),
    (1, '1'),
    (1, '1'));

  -- steep: far down and slightly to the right
  -- origin to (11,3) => 12 segments, each of width 1.
  constant expected_11_3: widthAndBump_t_vector := (
    (1, '0'),
    (1, '1'), -- vertical segment of size 2
    (1, '0'),
    (1, '0'),
    (1, '0'),
    (1, '1'), -- vertical segment of size 4
    (1, '0'),
    (1, '0'),
    (1, '0'),
    (1, '1'), -- vertical segment of size 4
    (1, '0'),
    (1, '1'));  -- vertical segment of size 2

  -- vertically down.
  -- origin to (11, 0) => 12 segments, each of width 1.
  constant expected_11_0: widthAndBump_t_vector := (
    (1, '0'),
    (1, '0'),
    (1, '0'),
    (1, '0'),
    (1, '0'),
    (1, '0'),
    (1, '0'),
    (1, '0'),
    (1, '0'),
    (1, '0'),
    (1, '0'),
    (1, '1'));
    
  -- one point
  -- origin to (0,0) => 1 segment.
  constant expected_0_0: widthAndBump_t_vector := ( 0 => (1, '1') );

  -- origin to (4, 6): 5 segments
  constant expected_4_6: widthAndBump_t_vector := (
    (1, '1'),
    (2, '1'),
    (1, '1'),
    (2, '1'),
    (1, '1'));

BEGIN
  uut: entity work.OriginZero(Behavioral)
  port map (
    clk => clk,
    yDelta => yDelta,
    xDelta => xDelta,
    start => start,
    ready => ready,
    moveNext => moveNext,
    segmentWidth => segmentWidth,
    shouldBumpX => shouldBumpX,
    done => done
  );

  clk <= not clk after clk_period/2;

  process
    procedure testHelper(yDelta_test: natural; xDelta_test: natural;
        fast: boolean;
        expected_results: widthAndBump_t_vector) is
      variable log_line: line;
    begin
      write(log_line, "starting " & natural'image(yDelta_test) & "," & natural'image(xDelta_test));
      if (fast) then
        write(log_line, ": fast");
      else
        write(log_line, ": slow");
      end if;
      report(log_line.all);
      deallocate(log_line);

      yDelta <= to_unsigned(yDelta_test, yDelta'Length);
      xDelta <= to_unsigned(xDelta_test, xDelta'Length);
      moveNext <= '0';
      start <= '1';
      wait for clk_period;
      start <= '0';
      
      while (ready = '0') loop
        wait for clk_period;
      end loop;
      yDelta <= (others => 'U');
      xDelta <= (others => 'U');
      for i in expected_results'low to expected_results'high loop
        if (not fast) then
          wait for 2*clk_period;
        end if;
        assert(done = '0') report("Prematurely done.");
        write(log_line, "index " & natural'image(i)
          & ": expected [segmentWidth=" & natural'image(expected_results(i).segmentWidth)
          & ", shouldBumpX=" & std_logic'image(expected_results(i).shouldBumpX)
          & "], got [segmentWidth=" & natural'image(to_integer(segmentWidth))
          & ", shouldBumpX=" & std_logic'image(shouldBumpX)
          & "]");
        assert(segmentWidth = expected_results(i).segmentWidth and
               shouldBumpX = expected_results(i).shouldBumpX)
            report (log_line.all);
        -- writeline(output, log_line);
        deallocate(log_line);

        moveNext <= '1';
        wait for clk_period;
        moveNext <= '0';
      end loop;
      assert(done = '1') report("Failed to report done");
    end procedure testHelper;

    procedure test(yDelta_test: natural; xDelta_test: natural;
      expected_results: widthAndBump_t_vector) is
    begin
      testHelper(yDelta_test, xDelta_test, true, expected_results);
      testHelper(yDelta_test, xDelta_test, false, expected_results);
    end procedure test;


  begin
      wait for clk_period*10;
      test(0, 11, expected_0_11);
      test(3, 11, expected_3_11);
      test(11, 11, expected_11_11);
      test(11, 3, expected_11_3);
      test(11, 0, expected_11_0);
      test(0, 0, expected_0_0);
      test(4, 6, expected_4_6);
      report "Test is done.";
      wait;
   end process;
END;
