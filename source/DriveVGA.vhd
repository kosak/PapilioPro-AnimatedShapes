library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.coord_t;
use work.util.CreatePoint;
use work.util.kCoordWidth;
use work.util.point_t;
use work.util.vgaColor_t;

entity DriveVGA is
  port (
    clk: in std_logic;
    
    -- Outputs that drive the VGA protocol.
    vga_red: out std_logic_vector(2 downto 0);
    vga_green: out std_logic_vector(2 downto 0);
    vga_blue: out std_logic_vector(1 downto 0);
    vga_hsync: out std_logic;
    vga_vsync: out std_logic;
    
    -- Control path for my pixel provider.
    frameStart: out std_logic;
    moveNext: out std_logic;
    
    -- Pixel coming back from my pixel provider.
    pixel: in vgaColor_t
  );
end DriveVGA;

architecture Behavioral of DriveVGA is
  signal pos, pos_1: point_t := CreatePoint(0, 0);
  signal frameStart_1: std_logic;

  signal vga_red_1: std_logic_vector(2 downto 0);
  signal vga_green_1: std_logic_vector(2 downto 0);
  signal vga_blue_1: std_logic_vector(1 downto 0);
  signal vga_hsync_1: std_logic;
  signal vga_vsync_1: std_logic;
  
  type state_t is (frontPorch, syncPulse, backPorch, visibleArea);
  signal vState, vState_1: state_t := frontPorch;
  signal hState, hState_1: state_t := frontPorch;
  
  -- These *Ends are the (exclusive) upper bounds of the range. For example, the front porch ranges
  -- from 0 to frontPorchEnd-1 inclusive.
  type limits_t is record
    frontPorchEnd: natural;
    syncPulseEnd: natural;
    backPorchEnd: natural;
    visibleEnd: natural;
  end record limits_t;

  -- Timings for 640x480 @ 60Hz (25.175 Mhz pixel clock)  
  constant vLimits: limits_t := (10, 12, 45, 525);
  constant hLimits: limits_t := (16, 112, 160, 800);

begin
        
  async: process(pos, vstate, hstate, pixel)
    function CalculateNextState(state: state_t; coord: coord_t; limits: limits_t) return state_t is
    begin
      case state is
        when frontPorch =>
          if (coord = limits.frontPorchEnd-1) then
            return syncPulse;
          end if;
        
        when syncPulse =>
          if (coord = limits.syncPulseEnd-1) then
            return backPorch;
          end if;
        
        when backPorch =>
          if (coord = limits.backPorchEnd-1) then
            return visibleArea;
          end if;
        
        when visibleArea =>
          if (coord = limits.visibleEnd-1) then
            return frontPorch;
          end if;
      end case;
      return state;  -- Default is to not change state.
    end function CalculateNextState;

  begin
    -- Bump to next coordinate and set next frameStart.
    pos_1.y <= pos.y;
    pos_1.x <= pos.x + 1;  -- Optimistically assume simple increment, no frame start.
    frameStart_1 <= '0';
    if (pos.x = hLimits.visibleEnd-1) then
      pos_1.x <= to_unsigned(0, pos_1.x'length);
      pos_1.y <= pos.y + 1;
      if (pos.y = vLimits.visibleEnd-1) then
        pos_1.y <= to_unsigned(0, pos_1.y'length);
        frameStart_1 <= '1';
      end if;
    end if;
    
    -- State machine logic.
    vState_1 <= vState;
    if (pos.x = hLimits.visibleEnd-1) then
      vState_1 <= CalculateNextState(vState, pos.y, vLimits);
    end if;
    hState_1 <= CalculateNextState(hState, pos.x, hLimits);
    
    -- sync logic
    vga_vsync_1 <= '1';  -- inverted logic.
    vga_hsync_1 <= '1';  -- inverted logic.
    if (vstate = syncPulse) then
      vga_vsync_1 <= '0';
    end if;
    if (hstate = syncPulse) then
      vga_hsync_1 <= '0';
    end if;
    
    -- pixel logic.
    if (vstate = visibleArea and hstate = visibleArea) then
      vga_red_1 <= std_logic_vector(pixel.r);
      vga_green_1 <= std_logic_vector(pixel.g);
      vga_blue_1 <= std_logic_vector(pixel.b);
      moveNext <= '1';
    else
      vga_red_1 <= (others => '0');
      vga_green_1 <= (others => '0');
      vga_blue_1 <= (others => '0');
      moveNext <= '0';
    end if;
  end process async;
    
  sync: process(clk)
  begin
    if (rising_edge(clk)) then
      pos <= pos_1;
      frameStart <= frameStart_1;
      vstate <= vstate_1;
      hstate <= hstate_1;
      vga_red <= vga_red_1;
      vga_green <= vga_green_1;
      vga_blue <= vga_blue_1;
      vga_vsync <= vga_vsync_1;
      vga_hsync <= vga_hsync_1;
    end if;  -- if (rising_edge(vga_clk)) then
  end process sync;

end Behavioral;
