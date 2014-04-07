library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.kCoordWidth;
use work.util.point_t;
use work.util.point_t_vector;
use work.util.vgaColor_t;

entity Main is
  port (
    clk: in std_logic;
    vga_red: out std_logic_vector(2 downto 0);
    vga_green: out std_logic_vector(2 downto 0);
    vga_blue: out std_logic_vector(1 downto 0);
    vga_hsync: out std_logic;
    vga_vsync: out std_logic
  );
end Main;

architecture Behavioral of Main is
  signal vga_clk: std_logic;
  -- Init the AnimatedShapes module
  signal start: std_logic;
  -- Wires from DriveVGA to AnimatedShapes.
  signal frameStart: std_logic;
  signal moveNext: std_logic;
  -- Wire from AnimatedShapes back to DriveVGA.
  signal pixel: vgaColor_t;
  
  type state_t is (idle, running);
  signal state, state_1: state_t := idle;

begin
  dcm: entity work.VGAClock
    port map (
      clk_in1 => clk,
      clk_out1 => vga_clk
    );
    
  vga: entity work.DriveVGA
    port map (
      clk => vga_clk,
		  vga_red => vga_red,
		  vga_green => vga_green,
		  vga_blue => vga_blue,
		  vga_hsync => vga_hsync,
		  vga_vsync => vga_vsync,
      frameStart => frameStart,
      moveNext => moveNext,
      pixel=> pixel
    );

  anim: entity work.AnimatedShapes
    generic map (
      kScreenHeight => 480,
      kScreenWidth => 640,
      kTestMode => 0
    )
    port map (
      clk => vga_clk,
      start => start,
      frameStart => frameStart,
      moveNext => moveNext,
      pixelColor => pixel
    );
  
  combinatorial: process(state) is
  begin
    case state is
      when idle =>
        state_1 <= running;
        start <= '1';
      
      when running =>
        state_1 <= running;
        start <= '0';
    end case;
  end process combinatorial;
    
  sync: process(vga_clk)
  begin
    if (rising_edge(vga_clk)) then
      state <= state_1;
    end if;
  end process sync;
end Behavioral;
