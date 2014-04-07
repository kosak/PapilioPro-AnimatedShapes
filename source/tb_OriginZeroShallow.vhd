LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use std.textio.all;
use work.util.kCoordWidth;
use work.util.coord_t;
use work.util.moveNextQueue_t;
use work.util.point_t;

ENTITY tb_OriginZeroShallow IS
END tb_OriginZeroShallow;

ARCHITECTURE behavior OF tb_OriginZeroShallow IS
  constant clk_period : time := 10 ns;
  
  signal clk: std_logic := '0';
  
  signal delta: point_t;
  signal start: std_logic;
  signal ready: std_logic;
    
  signal moveNext: std_logic;
  signal segmentWidth: coord_t;
  signal done: std_logic;

  type natural_vector is array(natural range<>) of integer;

  constant expected_0_11: natural_vector := (0 => 12);  -- (0,11) => [12]
  constant expected_3_11: natural_vector := (2, 4, 4, 2);  -- (3,11) => [2 4 4 2]
  constant expected_11_11: natural_vector := (1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1);  -- (11,11) => [12 * 1]
  constant expected_4_6: natural_vector := (1, 2, 1, 2, 1);  -- (4, 6) => [1, 2, 1, 2, 1]
  constant expected_0_0: natural_vector := (0 => 1);  -- (0, 0) => [1]

begin
  uut: entity work.OriginZeroShallow(Behavioral)
    port map (
      clk => clk,
      delta => delta,
      start => start,
      ready => ready,
      moveNext => moveNext,
      segmentWidth => segmentWidth,
      done => done
    );

  clk <= not clk after clk_period/2;

  stim_proc: process
    procedure testHelper(yDelta: natural; xDelta: natural; fast: boolean;
        expected_results: natural_vector) is
      variable log_line: line;
    begin
      write(log_line, "Testing (" & natural'image(yDelta) & "," & natural'image(xDelta) & ")");
      if (fast) then
        write(log_line, " - fast");
      else
        write(log_line, " - slow");
      end if;
      report(log_line.all);
      deallocate(log_line);

      delta.y <= to_unsigned(yDelta, delta.y'Length);
      delta.x <= to_unsigned(xDelta, delta.x'Length);
      moveNext <= '0';
      start <= '1';
      wait for clk_period;
      start <= '0';
      delta.y <= (others => 'U');
      delta.x <= (others => 'U');
      while (ready = '0') loop
        wait for clk_period;
      end loop;
      for i in expected_results'low to expected_results'high loop
        if (not fast) then
          wait for 2*clk_period;
        end if;
        assert(done = '0') report("Prematurely done.");
        write(log_line, "index " & natural'image(i) & ", expected " & natural'image(expected_results(i)) & ", got " & natural'image(to_integer(segmentWidth)));
        assert(segmentWidth = expected_results(i)) report (log_line.all);
        -- writeline(output, log_line);
        deallocate(log_line);
        moveNext <= '1';
        wait for clk_period;
        moveNext <= '0';
      end loop;
      assert(done = '1') report("Failed to report done");
    end procedure testHelper;

    procedure test(yDelta_test: natural; xDelta_test: natural;
      expected_results: natural_vector) is
    begin
      testHelper(yDelta_test, xDelta_test, true, expected_results);
      testHelper(yDelta_test, xDelta_test, false, expected_results);
    end procedure test;

  begin
      wait for clk_period*10;
      test(0, 11, expected_0_11);
      test(3, 11, expected_3_11);
      test(11, 11, expected_11_11);
      test(4, 6, expected_4_6);
      test(0, 0, expected_0_0);
      report "Test is finished.";
      wait;
   end process;

END;
