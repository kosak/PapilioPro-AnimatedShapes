-- Draws a line from (0,0) to (yDelta,xDelta). The coordinate system has (0,0) at the upper left
-- hand corner of the screen. Requires yDelta <= xDelta (i.e. the line must have an angle between 315
-- and 360 degrees). This is the innermost module in a chain of modules, each of which adds
-- flexibility. The outermost module is able to draw lines between arbitrary points.
--
-- Returns a sequence of segment widths. The caller should advance their y position by 1 after each
-- element, and increment their x position by the segment width. For example, the input (3,11)
-- (representing the line from (0,0) to (y=3,x=11) would yield the sequence [2 4 4 2]. Graphically
-- this might be drawn as:
--
-- XX
--   XXXX
--       XXXX
--           XX
--
-- The sequence generated has length at least 1. Furthermore every element in the sequence has
-- a value of at least 1 (i.e. segmentWidth=0 is impossible).
--
-- The endpoints of the line are inclusive, so even the "degenerate" input (yDelta=0, xDelta=0)
-- (representing the line that starts and ends at (0,0)) returns a one-element sequence containing
-- the value 1. Graphically this might be drawn as :-)
--
-- X
--
-- ===== USAGE =====
--
-- Most of the cooperating modules in this program work as a pipeline. Modules in a pipeline adhere
-- to the following protocol. For the sake of this discussion we refer to a module and its upstream
-- counterpart as "master" and "slave".
--
-- Modules have a setup phase, which is allowed to take "a while", and then a data production phase,
-- which is required to be able to produce a new value on every cycle. Saying the setup phase takes
-- "a while" is deliberately left vague, but for this project it means "less time than a vertical
-- blanking interval".
--
-- The data production phase yields an infinite sequence of tuples of the form <done, value>. When
-- there are values to present, the done flag is 0. When the sequence reaches its logical end,
-- the done flag is set to 1, and all subsequent elements in the sequence will have their done flag
-- set to 1. For example, the sequence [3 4 5] would look like:
-- ('0',3), ('0',4), ('0',5), ('1',dontcare), ('1',dontcare), ('1',dontcare), ...
--
-- The master initiates the setup phase by setting the input parameters to the slave, and pulsing
-- "start". These inputs must be held steady until the slave asserts "ready". The slave will do
-- its necessary setup calculations (taking however many cycles it needs to), present the first
-- value in the sequence, and then assert 'ready'.
--
-- Subsequent to that point, the slave needs to be able to produce the next value in the sequence in
-- one cycle, on demand, when the master asserts moveNext.
--
-- Here is a sample interaction for a slave that returns the three elements [3 4 5].
--
-- Cycle 0:
--   Master sets up input parameters, pulses 'start' for one cycle.
--
-- Cycle 1..R-1
--   Master waits for slave to assert 'ready'.
--
-- Cycle R:
--   Slave makes first element available on its outputs, asserts 'ready'. In this example the
--   output value is 3. Master is eager, consumes the 3, asserts moveNext. Slave sees moveNext,
--   starts working on its next output.
--
-- Cycle R+1:
--   Slave has 4 on its output. Master is not ready to consume the 4, holds moveNext low.
--
-- then after some time:
--   Master consumes the 4, asserts moveNext. Slave sees moveNext and starts working on its next
--   value.
--
-- after 1 more cycle:
--   Slave has 5 on its output. Master is eager again, consumes the 5, asserts moveNext. Slave sees
--   moveNext and starts working on its next value.
--
-- after 1 more cycle:
--   Slave asserts done='1'. Master sees this and realizes slave will not generate any more values.
--   It is OK to keep asserting moveNext, but this will not change done=1. The only way to get a new
--   sequence is to go back to the "set up" phase.
--
-- Note that it can take worse case O(xDelta) time for ready to be asserted. This is because the
-- algorithm does a simplistic subtraction algorithm instead of computing div and mod. This is very
-- cheap in terms of gates, and it doesn't present a serious drawback in practice, as the div/mod
-- is only be done once per line drawn (and therefore typically can be done in the vertical blanking
-- period).
--
-- ===== THE ALGORITHM =====
--
-- This is an implementation of Bresenham's algorithm. I copied the core algorithm pretty closely
-- from Michael Abrash's Graphics Programming Black Book Special Edition"
-- (http://www.phatcode.net/res/224/files/html/ch36/36-03.html) but I adapted it to my way of
-- thinking, and to VHDL.
--
-- The algorithm requires a division and a mod operation during the "setup" phase. Realizing that I
-- have a lot of time during the setup phase (in real life, corresponding to the vertical blank on
-- the VGA display), I implement this operation using repeated subtraction, which as a side-effect
-- gives me the quotient and the remainder at the same time. The most costly divmod I will ever be
-- asked to perfom is kScreenWidth/1, which takes 'kScreenWidth' cycles to calculate using this
-- simplistic algorithm. Since that can be accomplished in one scan line, it easily fits into my
-- budget.
--
-- Of course, I could synthesize the division and mod operation, but that would use up a lot of gates.
-- Or I could use one of the dedicated arithmetic units. However, given that I have lots of time
-- during every vertical blanking interval, the above works very well.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.kCoordWidth;
use work.util.coord_t;
use work.util.point_t;

entity OriginZeroShallow is
  port (
    clk: in std_logic;
    
    delta: in point_t;
    start: in std_logic;
    ready: out std_logic;
    
    moveNext: in std_logic;
    segmentWidth: out coord_t;
    done: out std_logic
  );
end OriginZeroShallow;

architecture Behavioral of OriginZeroShallow is
  type state_t is (divModding, calculatingInitialSegment, running, idle);
  signal state, state_1: state_t := idle;
  
  signal latchedYDelta, latchedYDelta_1: unsigned(kCoordWidth-1 downto 0);
  signal xDeltaDivYDelta, xDeltaDivYDelta_1: unsigned(kCoordWidth-1 downto 0);
  signal xDeltaModYDelta, xDeltaModYDelta_1: unsigned(kCoordWidth-1 downto 0);
  signal wholeStep, wholeStep_1: unsigned(kCoordWidth-1 downto 0);
  signal adjUp, adjUp_1: unsigned(kCoordWidth-1 downto 0);
  signal adjDown, adjDown_1: unsigned(kCoordWidth-1 downto 0);
  signal finalPixelCount, finalPixelCount_1: unsigned(kCoordWidth-1 downto 0);
  signal errorTerm, errorTerm_1: signed(kCoordWidth downto 0);  -- 1 bit wider, and signed.
  signal segmentWidth_0, segmentWidth_1: unsigned(kCoordWidth-1 downto 0);
  signal segmentsLeft, segmentsLeft_1: unsigned(kCoordWidth-1 downto 0);
  
begin
  combinatorial: process(start, moveNext, state, xDeltaDivYDelta, xDeltaModYDelta, latchedYDelta,
    wholeStep, adjUp, adjDown, finalPixelCount, errorTerm, segmentWidth_0, segmentsLeft)
    variable initialPixelCount_temp: coord_t;
    variable errorTerm_temp: signed(kCoordWidth downto 0);  -- 1 bit wider, and signed.
    
    procedure CalculateInitialSegment is
    begin
      wholeStep_1 <= xDeltaDivYDelta;
      -- Error term adjust each time Y steps by 1; used to tell when one
      -- extra pixel should be drawn as part of a run, to account for
      -- fractional steps along the X axis per 1-pixel steps along Y.
      adjUp_1 <= xDeltaModYDelta;

      -- Error term adjust when the error term turns over, used to factor
      -- out the X step made at that time.
      adjDown_1 <= latchedYDelta;

      -- The initial and last runs are partial, because Y advances only 0.5
      -- for these runs, rather than 1. Divide one full run, plus the
      -- initial pixel, between the initial and last runs.
      initialPixelCount_temp := (xDeltaDivYDelta / 2) + 1;

      -- If the basic run length is even and there's no fractional
      -- advance, we have one pixel that could go to either the initial
      -- or last partial run, which we'll arbitrarily allocate to the
      -- last run.
      if (xDeltaModYDelta = 0) and (xDeltaDivYDelta(0) = '0') then
        segmentWidth_1 <= initialPixelCount_temp - 1;
      else
        segmentWidth_1 <= initialPixelCount_temp;
      end if;
      finalPixelCount_1 <= initialPixelCount_temp;

      -- Initial error term; reflects an initial step of 0.5 along the Y axis.
      errorTerm_temp := signed(xDeltaModYDelta) - signed(latchedYDelta & "0");

      -- If there're an odd number of pixels per run, we have 1 pixel that can't
      -- be allocated to either the initial or last partial run, so we'll add 0.5
      -- to error term so this pixel will be handled by the normal full-run loop
      if (xDeltaDivYDelta(0) = '1') then
        errorTerm_1 <= errorTerm_temp + signed(latchedYDelta);
      else
        errorTerm_1 <= errorTerm_temp;
      end if;
      segmentsLeft_1 <= latchedYDelta;  -- number of segments remaining (excluding first).
    end procedure CalculateInitialSegment;
    
  begin
    xDeltaModYDelta_1 <= xDeltaModYDelta;
    xDeltaDivYDelta_1 <= xDeltaDivYDelta;
    latchedYDelta_1 <= latchedYDelta;
    wholeStep_1 <= wholeStep;
    adjUp_1 <= adjUp;
    adjDown_1 <= adjDown;
    errorTerm_1 <= errorTerm;
    segmentsLeft_1 <= segmentsLeft;
    finalPixelCount_1 <= finalPixelCount;
    segmentWidth_1 <= segmentWidth_0;

    -- output
    segmentWidth <= segmentWidth_0;
    
    -- ready logic
    case state is
      when running => ready <= not start;
      when others => ready <= '0';
    end case;
    
    -- done logic
    case state is
      when idle => done <= '1';
      when others => done <= '0';
    end case;
    
    state_1 <= state;  -- Default is to loop.
    
    case state is
      when divModding =>
        if (xDeltaModYDelta >= latchedYDelta) then
          xDeltaModYDelta_1 <= xDeltaModYDelta - latchedYDelta;
          xDeltaDivYDelta_1 <= xDeltaDivYDelta + 1;
        else
          state_1 <= calculatingInitialSegment;
        end if;
        
      when calculatingInitialSegment =>
        CalculateInitialSegment;
        state_1 <= running;
        
      when running =>
        if (moveNext = '1') then
          if (segmentsLeft = 0) then
            segmentWidth_1 <= (others => 'U');
            state_1 <= idle;
          elsif (segmentsLeft = 1) then
            segmentWidth_1 <= finalPixelCount;
            segmentsLeft_1 <= to_unsigned(0, segmentsLeft_1'length);
          else
            errorTerm_temp := errorTerm + signed(adjUp & "0");  -- aka adjUp * 2
            -- Advance the error term and add an extra pixel if the error term so indicates.
            if (errorTerm_temp > 0) then
              segmentWidth_1 <= wholeStep + 1;
              errorTerm_temp := errorTerm_temp - signed(adjDown & "0");  -- aka adjDown * 2.
            else
              segmentWidth_1 <= wholeStep;
            end if;
            errorTerm_1 <= errorTerm_temp;
            segmentsLeft_1 <= segmentsLeft - 1;
          end if;
        end if;  -- if (moveNext = '1') then
        
      when idle =>
        wholeStep_1 <= (others => 'U');
        adjUp_1 <= (others => 'U');
        adjDown_1 <= (others => 'U');
        errorTerm_1 <= (others => 'U');
        segmentsLeft_1 <= (others => 'U');
        finalPixelCount_1 <= (others => 'U');
        segmentWidth_1 <= (others => 'U');

    end case;
  end process combinatorial;

  sync: process(clk)
  begin
    if (rising_edge(clk)) then
      if (start = '1') then
        if (delta.y = 0) then
          -- special case when denominator is zero (horizontal line).
          segmentWidth_0 <= delta.x + 1;
          segmentsLeft <= to_unsigned(0, segmentsLeft_1'length);
          state <= running;
        else
          latchedYDelta <= delta.y;
          xDeltaModYDelta <= delta.x;
          xDeltaDivYDelta <= to_unsigned(0, xDeltaDivYDelta'length);
          state <= divModding;
        end if;  -- if (delta.y = 0)
      else
        state <= state_1;
        latchedYDelta <= latchedYDelta_1;
        xDeltaDivYDelta <= xDeltaDivYDelta_1;
        xDeltaModYDelta <= xDeltaModYDelta_1;
        
        wholeStep <= wholeStep_1;
        adjUp <= adjUp_1;
        adjDown <= adjDown_1;
        finalPixelCount <= finalPixelCount_1;
        errorTerm <= errorTerm_1;
        segmentWidth_0 <= segmentWidth_1;
        segmentsLeft <= segmentsLeft_1;
      end if; -- if (start = '1')
    end if;  -- if (rising_edge(clk))
  end process sync;

end Behavioral;
