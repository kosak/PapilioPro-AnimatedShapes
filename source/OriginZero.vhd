-- Draws a line from (0,0) to (yDelta,xDelta). The coordinate system has (0,0) at the upper left
-- hand corner of the screen. The angle of the line is between 270 and 360 degrees (i.e.
-- straight down, straight to the right, or somewhere in between). Returns a sequence of pairs
-- (segmentWidth, shouldBump) which should be interpreted by the caller according to this pseudocode:
--
-- ypos=0
-- xpos=0
-- foreach (segmentWidth, shouldBump) in OriginZero(...)
--   Draw a horizontal segment of width 'segmentWidth' starting at (ypos,xpos)
--   ++ypos
--   if (shouldBump)
--     xpos += segmentWidth
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.coord_t;
use work.util.kCoordWidth;
use work.util.point_t;
use work.util.xposAndSegmentWidth_t;

entity OriginZero is
  port (
    clk: in std_logic;

    yDelta: in coord_t;
    xDelta: in coord_t;

    start: in std_logic;
    ready: out std_logic;
    
    moveNext: in std_logic;
    segmentWidth: out coord_t;
    shouldBumpX: out std_logic;
    done: out std_logic
  );
end OriginZero;

architecture Behavioral of OriginZero is
  type slaveInterface_t is
  record
    delta: point_t;
    start: std_logic;
    ready: std_logic;
    
    segmentWidth: coord_t;
    done: std_logic;
    moveNext: std_logic;
  end record;
  
  type state_t is (idle,
      waitReadyShallow, waitReadySteep,
      shallowFirstTime, shallow,
      steepFirstTime, steep,
      steepLoop);

  signal slave: slaveInterface_t;
  signal state, state_1: state_t := idle;
  
  signal segmentWidth_0, segmentWidth_1: coord_t;
  signal shouldBumpX_0, shouldBumpX_1: std_logic;
  signal remaining, remaining_1: coord_t;
  
begin
  originZeroShallow: entity work.OriginZeroShallow(Behavioral)
    port map (
      clk => clk,
      delta => slave.delta,
      start => slave.start,
      ready => slave.ready,
      segmentWidth => slave.segmentWidth,
      done => slave.done,
      moveNext => slave.moveNext
    );

  combinatorial: process(state, slave, start, moveNext, remaining,
      segmentWidth_0, shouldBumpX_0)
  begin
    -- outputs
    segmentWidth <= segmentWidth_0;
    shouldBumpX <= shouldBumpX_0;
    
    -- registers
    segmentWidth_1 <= segmentWidth_0;
    shouldBumpX_1 <= shouldBumpX_0;
    remaining_1 <= remaining;
    state_1 <= state;  -- Default is to loop.

    -- defaults
    slave.moveNext <= '0';
    
    -- ready logic
    case state is
      when shallow | steep | steepLoop => ready <= not start;
      when others => ready <= '0';
    end case;
    
    -- done logic
    case state is
      when idle => done <= '1';
      when others => done <= '0';
    end case;
    
    case state is
      when idle =>
        remaining_1 <= (others => 'U');
        
      when waitReadyShallow =>
        if (slave.ready = '1') then
          state_1 <= shallowFirstTime;
        end if;  -- if (slave.ready = '1') then

      when waitReadySteep =>
        if (slave.ready = '1') then
          state_1 <= steepFirstTime;
        end if;  -- if (slave.ready = '1') then
      
      when shallowFirstTime|shallow =>
        state_1 <= shallow;  -- Default is to loop.
        if (state = shallowFirstTime or moveNext = '1') then
          if (slave.done = '1') then
            state_1 <= idle;
          else
            segmentWidth_1 <= slave.segmentWidth;
            shouldBumpX_1 <= '1';
            slave.moveNext <= '1';
          end if;
        end if;  -- if (state = shallowFirstTime or moveNext = '1')
        
      when steepFirstTime|steep =>
        state_1 <= steep;  -- Default is to loop.
        if (state = steepFirstTime or moveNext = '1') then
          if (slave.done = '1') then
            state_1 <= idle;
          else
            segmentWidth_1 <= to_unsigned(1, segmentWidth_1'length);
            slave.moveNext <= '1';
            if (slave.segmentWidth = 1) then
              shouldBumpX_1 <= '1';
            else -- segmentWidth is greater than 1
              shouldBumpX_1 <= '0';
              remaining_1 <= slave.segmentWidth - 1;
              state_1 <= steepLoop;
            end if;  -- if (slave.segmentWidth = 1)
          end if;  
        end if;  -- if (state = steepFirstTime or moveNext = '1')

      when steepLoop =>
        if (moveNext = '1') then
          segmentWidth_1 <= to_unsigned(1, segmentWidth_1'length);
          if (remaining = 1) then
            shouldBumpX_1 <= '1';
            state_1 <= steep;
          else -- remaining > 1
            shouldBumpX_1 <= '0';
            remaining_1 <= remaining - 1;
          end if;  -- if (slave.segmentWidth = 1)
        end if;  -- if (state = steepFirstTime or moveNext = '1')
    end case;
  end process combinatorial;

  sync: process(clk)
    procedure DoStart is
    begin
      if (xDelta >= yDelta) then
        slave.delta.y <= yDelta;
        slave.delta.x <= xDelta;
        state <= waitReadyShallow;
      else
        slave.delta.y <= xDelta;  -- swapping coords turns steep into shallow!
        slave.delta.x <= yDelta;
        state <= waitReadySteep;
      end if;  -- if (xDelta >= yDelta)
    end procedure DoStart;

  begin
    if (rising_edge(clk)) then
      if (start = '1') then
        DoStart;
        slave.start <= '1';
      else
        slave.start <= '0';
        segmentWidth_0 <= segmentWidth_1;
        shouldBumpX_0 <= shouldBumpX_1;
        remaining <= remaining_1;
        state <= state_1;
      end if;  -- if (start = '1')
    end if;  -- if (rising_edge(clk))
  end process sync;

end Behavioral;
