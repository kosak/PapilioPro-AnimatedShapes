-- Draws a line from 'first' to 'last' where first and last are both (y,x) pairs. The coordinate
-- system has (0,0) at the upper left hand corner of the screen. The points are returned in the
-- order that they would be painted on the screen; i.e. (point p0 comes before point p1) iff
-- ((p0.y < p1.y) or (p0.y == p1.y and p0.x < p1.x)). This ordering happens to be useful, for, e.g.,
-- painting points on a VGA screen without needing a frame buffer.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.kCoordWidth;
use work.util.coord_t;
use work.util.point_t;
use work.util.xposAndSegmentWidth_t;

entity ArbitraryLine is
  port (
    clk: in std_logic;
    
    first: in point_t;
    last: in point_t;
    start: in std_logic;
    ready: out std_logic;
    
    moveNext: in std_logic;
    point: out point_t;
    done: out std_logic
  );
end ArbitraryLine;

architecture Behavioral of ArbitraryLine is
  type slaveInterface_t is
  record
    yDelta: coord_t;
    xDelta: coord_t;
    start: std_logic;
    ready: std_logic;
    
    moveNext: std_logic;
    segmentWidth: coord_t;
    shouldBumpX: std_logic;
    done: std_logic;
  end record;

  type state_t is (idle, waitReady, running, runningFirstTime, looping);
  signal state, state_1: state_t := idle;
  
  type direction_t is (leftToRight, rightToLeft);
  signal direction, direction_1: direction_t;
  
  signal slave: slaveInterface_t;
  
  signal cursor, cursor_1: point_t;
  signal point_0, point_1: point_t;
  
  signal remaining, remaining_1: coord_t;
  

begin
	originZero: entity work.OriginZero(Behavioral)
  port map(
		clk => clk,
    yDelta => slave.yDelta,
    xDelta => slave.xDelta,
    start => slave.start,
    ready => slave.ready,
    moveNext => slave.moveNext,
    segmentWidth => slave.segmentWidth,
    shouldBumpX => slave.shouldBumpX,
    done => slave.done
	);

  combinatorial: process(start, moveNext, state, direction, slave, cursor, point_0, remaining)
  begin
    -- outputs
    point <= point_0;

    -- Registers.
    cursor_1 <= cursor;
    point_1 <= point_0;
    remaining_1 <= remaining;
    state_1 <= state;  -- Default is to loop.
    
    -- Default for slave is to not move.
    slave.moveNext <= '0';
    
    -- ready logic
    case state is
      when running|looping => ready <= not start;
      when others => ready <= '0';
    end case;
    
    -- done logic
    case state is
      when idle => done <= '1';
      when others => done <= '0';
    end case;

    case state is
      when idle =>
        
      when waitReady =>
        if (slave.ready = '1') then
          state_1 <= runningFirstTime;
        end if;  -- if (slave.ready = '1')
        
      when runningFirstTime|running =>
        state_1 <= running;  -- Default is to loop back to running state.
        if (state = runningFirstTime or moveNext = '1') then
          if (slave.done = '1') then
            state_1 <= idle;
          else
            -- point calculation
            point_1.y <= cursor.y;
            if (direction = leftToRight) then
              point_1.x <= cursor.x;
            else
              point_1.x <= cursor.x - slave.segmentWidth + 1;
            end if;  -- if (direction = leftToRight)
            
            -- bump cursor
            cursor_1.y <= cursor.y + 1;
            if (slave.shouldBumpX = '1') then
              if (direction = leftToRight) then
                cursor_1.x <= cursor.x + slave.segmentWidth;
              else
                cursor_1.x <= cursor.x - slave.segmentWidth;
              end if;  -- if (direction = leftToRight)
            end if;  -- if (slave.shouldBumpX = '1')
            
            slave.moveNext <= '1';
            if (slave.segmentWidth /= 1) then
              remaining_1 <= slave.segmentWidth - 1;
              state_1 <= looping;
            end if;
          end if;  -- if (slave.done = '1') then
        end if;  -- if (state = runningFirst or moveNext = '1')
        
      when looping =>
        if (moveNext = '1') then
          point_1.x <= point_0.x + 1;
          remaining_1 <= remaining - 1;
          if (remaining = 1) then
            state_1 <= running;
          end if;
        end if;  -- if (moveNext = '1')
    end case;
  end process combinatorial;
  
  sync: process(clk)
    procedure DoStart is
      variable fst, lst: point_t;
    begin
      -- Canonicalize first and last so that the y coordinate is nondecreasing.
      -- (In other words, just swap the two points if they're going the wrong way).
      if (first.y <= last.y) then
        fst := first;
        lst := last;
      else
        fst := last;  -- swap
        lst := first;
      end if;
      cursor.y <= fst.y;
      slave.yDelta <= lst.y - fst.y;  -- Nonnegative.
      
      -- Now calculate xDelta and figure out the direction
      cursor.x <= fst.x;
      if (fst.x <= lst.x) then
        slave.xDelta <= lst.x - fst.x;  -- Nonnegative.
        direction <= leftToRight;
      else
        slave.xDelta <= fst.x - lst.x;  -- Nonnegative.
        direction <= rightToLeft;
      end if;  -- if (fst.x <= lst.x)
      state <= waitReady;
    end procedure DoStart;
    
  begin
    if (rising_edge(clk)) then
      if (start = '1') then
        DoStart;
        slave.start <= '1';
      else
        slave.start <= '0';
        cursor <= cursor_1;
        point_0 <= point_1;
        remaining <= remaining_1;
        state <= state_1;
      end if; -- if (start = '1')
    end if;  -- if (rising_edge(clk))
  end process sync;

end Behavioral;
