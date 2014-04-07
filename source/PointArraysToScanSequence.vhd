library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.coord_t;
use work.util.kCoordWidth;
use work.util.pixel_t;
use work.util.point_t;
use work.util.point_t_vector;
use work.util.pointOrDone_t;

entity PointArraysToScanSequence is
  generic (numComponents: positive;
      kScreenHeight: positive;
      kScreenWidth: positive
  );
  port (
    clk: in std_logic;
    -- Control in.
    start: in std_logic;
    moveNext: in std_logic;
    
    -- Control out.
    ready: out std_logic;
    
    -- Data out.
    pixelActive: out std_logic;
    
    -- Slave control path.
    slaveStarts: out std_logic_vector(0 to numComponents-1);
    slaveReadys: in std_logic_vector(0 to numComponents-1);
    slaveMoveNexts: out std_logic_vector(0 to numComponents-1);
    
    -- Slave outputs (inputs relative to this module).
    slavePoints: in point_t_vector(0 to numComponents-1);
    slaveDones: in std_logic_vector(0 to numComponents-1)
  );
end PointArraysToScanSequence;

architecture Behavioral of PointArraysToScanSequence is
  signal cursor, cursor_1: point_t;
  
  type state_t is (idle, waitReady, running);
  signal state, state_1: state_t;
  
begin
  combinatorial: process(state, start, moveNext, slaveReadys, slavePoints, slaveDones, cursor)
    variable slavePixels_temp: std_logic_vector(0 to numComponents-1);
  begin
    -- Pessimistically assume that cursor does not move...
    cursor_1 <= cursor;
    -- and that pixel is inactive...
    pixelActive <= '0';
    -- and that slaves do not need to be advanced.
    for i in 0 to numComponents-1 loop
      slaveMoveNexts(i) <= '0';
    end loop;
    
    -- ready logic
    case state is
      when running => ready <= not start;
      when others => ready <= '0';
    end case;

    case state is
      when idle =>
        state_1 <= idle;

      when waitReady =>
        state_1 <= running;  -- Optimistically advance to running state...
        for i in 0 to numComponents-1 loop
          if (slaveReadys(i) = '0') then
            state_1 <= waitReady;  -- ...but any slave not being ready vetoes that decision.
          end if;  -- if (slaveReadys(i) = '0')
        end loop;
        
      when running =>
        state_1 <= running;
        -- Calculate slavePixels_temp.
        slavePixels_temp := (others => '0');
        for i in 0 to numComponents-1 loop
          if (slaveDones(i) = '0'
              and slavePoints(i).y = cursor.y
              and slavePoints(i).x = cursor.x) then
            pixelActive <= '1';
            slavePixels_temp(i) := '1';
          end if;
        end loop;

        -- If moveNext is enabled, advance slave moveNexts and cursor.
        if (moveNext = '1') then
          -- Advance slaveMoveNexts
          slaveMoveNexts <= slavePixels_temp;

          -- Advance cursor.
          if (cursor.x /= kScreenWidth-1) then
            cursor_1.x <= cursor.x + 1;
            cursor_1.y <= cursor.y;
          else
            cursor_1.x <= to_unsigned(0, cursor_1.x'length);
            if (cursor.y /= kScreenHeight-1) then
              cursor_1.y <= cursor.y + 1;
            else
              state_1 <= idle;
            end if;  -- if (cursor.y /= kScreenHeight-1)
          end if;  -- if (cursor.x /= kScreenWidth-1)
        end if;  -- if (moveNext = '1') then
    end case;
  end process combinatorial;

  sync: process(clk)
    procedure DoStart is
    begin
      cursor.y <= to_unsigned(0, cursor.y'length);
      cursor.x <= to_unsigned(0, cursor.x'length);
      for i in 0 to numComponents-1 loop
        slaveStarts(i) <= '1';
      end loop;
      state <= waitReady;
    end procedure DoStart;

    procedure ClearSlaveStarts is
    begin
      for i in 0 to numComponents-1 loop
        slaveStarts(i) <= '0';
      end loop;
    end procedure ClearSlaveStarts;

  begin
    if (rising_edge(clk)) then
      if (start = '1') then
        DoStart;
      else
        ClearSlaveStarts;
        state <= state_1;
        cursor <= cursor_1;
      end if;  -- if (start = '1')
    end if;  -- if (rising_edge(clk))
  end process;
end Behavioral;
