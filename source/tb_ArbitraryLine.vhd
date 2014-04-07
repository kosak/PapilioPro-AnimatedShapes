LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use std.textio.all;
use work.util.kCoordWidth;
use work.util.coord_t;
use work.util.point_t;
use work.util.xposAndSegmentWidth_t;
 
ENTITY tb_ArbitraryLine IS
END tb_ArbitraryLine;
 
ARCHITECTURE behavior OF tb_ArbitraryLine IS 
  --Inputs
  signal clk : std_logic := '0';
  signal first: point_t;
  signal last: point_t;
  signal start : std_logic;
  signal moveNext : std_logic;

 	--Outputs
  signal point: point_t;
  signal ready : std_logic;
  signal done : std_logic;

  -- Clock period definitions
  constant clk_period : time := 10 ns;
  
  type expectedPoint_t is
  record
    ypos: natural;
    xpos: natural;
  end record;
  
  type point_vector_t is array(natural range<>) of expectedPoint_t;

  -- one point.
  constant expected_100_200_100_200: point_vector_t := (0 => (100, 200));
  
  -- horizontal to the right.
  constant expected_100_200_100_204: point_vector_t := (
    (100, 200), (100, 201), (100, 202), (100, 203), (100, 204));
    
  -- vertical down.
  constant expected_100_200_104_200: point_vector_t := (
    (100, 200), (101, 200), (102, 200), (103, 200), (104, 200));
    
  -- 45 degrees right and down.
  constant expected_100_200_104_204: point_vector_t := (
    (100, 200), (101, 201), (102, 202), (103, 203), (104, 204));

  -- 45 degrees right and up.
  constant expected_100_200_96_204: point_vector_t := (
    (96, 204), (97, 203), (98, 202), (99, 201), (100, 200));

  -- shallow to the right and down.
  constant expected_100_200_103_211: point_vector_t := (
    (100, 200), (100, 201),
    (101, 202), (101, 203), (101, 204), (101, 205),
    (102, 206), (102, 207), (102, 208), (102, 209),
    (103, 210), (103, 211));

  -- shallow to the right and up.
  constant expected_100_200_97_211: point_vector_t := (
    (97, 210), (97, 211),
    (98, 206), (98, 207), (98, 208), (98, 209),
    (99, 202), (99, 203), (99, 204), (99, 205),
    (100, 200), (100, 201));
    
  -- steep to the right and down.
  constant expected_100_200_111_203: point_vector_t := (
    (100, 200), (101, 200),
    (102, 201), (103, 201), (104, 201), (105, 201),
    (106, 202), (107, 202), (108, 202), (109, 202),
    (110, 203), (111, 203));
    
  -- steep to the right and up.
  constant expected_100_200_89_203: point_vector_t := (
    (89, 203), (90, 203),
    (91, 202), (92, 202), (93, 202), (94, 202),
    (95, 201), (96, 201), (97, 201), (98, 201),
    (99, 200), (100, 200));
    
  -- A short sequence used for the "early abort" test.
  constant early_abort: point_vector_t := ((0, 0), (0, 1), (0, 2));
 
begin
  uut: entity work.ArbitraryLine(Behavioral)
  port map(
    clk => clk,
    first => first,
    last => last,
    start => start,
    moveNext => moveNext,
    ready => ready,
    point => point,
    done => done
  );
   
  clk <= not clk after clk_period/2;

  stim_proc: process
    procedure testHelper2(prefix: string;
        y0_arg: natural; x0_arg: natural;
        y1_arg: natural; x1_arg: natural;
        fast: boolean;
        isEarlyAbort: boolean;
        expectedResults: point_vector_t) is
      variable temp: expectedPoint_t;
      variable text: line;
    begin
      write(text, "Testing " & prefix);
      if (fast) then
        write(text, " (fast) ");
      else
        write(text, " (slow) ");
      end if;
        
      write(text, ": "
        & "(" & natural'image(y0_arg) & "," & natural'image(x0_arg) & ")-"
        & "(" & natural'image(y1_arg) & "," & natural'image(x1_arg) & ")");
      report(text.all);
      deallocate(text);

      first.y <= to_unsigned(y0_arg, first.y'Length);
      first.x <= to_unsigned(x0_arg, first.x'Length);
      last.y <= to_unsigned(y1_arg, last.y'Length);
      last.x <= to_unsigned(x1_arg, last.x'Length);
      start <= '1';
      moveNext <= '0';
      wait for clk_period;
      start <= '0';
      first.y <= (others => 'U');
      first.x <= (others => 'U');
      last.y <= (others => 'U');
      last.x <= (others => 'U');
      while (ready = '0') loop
        wait for clk_period;
      end loop;
      for i in expectedResults'low to expectedResults'high loop
        if (not fast) then
          wait for 2*clk_period;
        end if;
        assert(done = '0') report("Prematurely done.");
        temp := expectedResults(i);
        write(text, prefix
          & ": index " & natural'image(i)
          & ": expected "
          & natural'image(temp.ypos) & "," & natural'image(temp.xpos)
          & "; got "
          & natural'image(to_integer(point.y)) & "," & natural'image(to_integer(point.x)));
        assert(point.y = temp.ypos and point.x = temp.xpos) report (text.all);
        -- writeline(output, log_line);
        deallocate(text);

        moveNext <= '1';
        wait for clk_period;
        moveNext <= '0';
      end loop;
      if (not isEarlyAbort) then
        assert(done = '1') report("Failed to report done");
      end if;
    end procedure testHelper2;
  
    procedure testHelper1(prefix: string; y0: natural; x0: natural; y1: natural; x1: natural;
        isEarlyAbort: boolean; expectedResults: point_vector_t) is
    begin
      testHelper2(prefix, y0, x0, y1, x1, true, isEarlyAbort, expectedResults);
      testHelper2(prefix, y0, x0, y1, x1, false, isEarlyAbort, expectedResults);
    end procedure testHelper1;

    procedure test(y0_arg: natural; x0_arg: natural; y1_arg: natural; x1_arg: natural;
        expectedResults: point_vector_t) is
    begin
      testHelper1("normal", y0_arg, x0_arg, y1_arg, x1_arg, false, expectedResults);
      testHelper1("reversed", y1_arg, x1_arg, y0_arg, x0_arg, false, expectedResults);
    end procedure test;

  begin		
    wait for clk_period*10;
    test(100, 200, 100, 200, expected_100_200_100_200);  -- one point.
    test(100, 200, 100, 204, expected_100_200_100_204);  -- horizontal to the right.
    test(100, 200, 104, 200, expected_100_200_104_200);  -- vertical down.
    test(100, 200, 104, 204, expected_100_200_104_204);  -- 45 degrees right and down.
    test(100, 200, 96, 204, expected_100_200_96_204);  -- 45 degrees right and up.
    test(100, 200, 103, 211, expected_100_200_103_211);  -- shallow to the right and down.
    test(100, 200, 97, 211, expected_100_200_97_211);  -- shallow to the right and up.
    test(100, 200, 111, 203, expected_100_200_111_203);  -- steep to the right and down.
    test(100, 200, 89, 203, expected_100_200_89_203);  -- steep to the right and up.
    
    testHelper1("early abort", 0, 0, 1, 50, true, early_abort);
    testHelper1("still works after abort", 100, 200, 111, 203, false, expected_100_200_111_203);
    report("tests finished.");
    wait;
  end process;
end;
