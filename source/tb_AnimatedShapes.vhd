LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
use std.textio.all;
use work.util.vgaColor_t;
use work.util.ToString;
use work.util.CreateVgaColor;

 
ENTITY tb_AnimatedShapes IS
END tb_AnimatedShapes;
 
ARCHITECTURE behavior OF tb_AnimatedShapes IS
  constant clk_period : time := 10 ns;
  constant kScreenHeight: positive:= 7;
  constant kScreenWidth: positive:= 7;
  constant kNumFrames: positive := 3;

  --Inputs
  signal clk: std_logic := '0';
  signal start: std_logic := '0';
  signal frameStart: std_logic;
  signal moveNext: std_logic;
  signal pixelColor: vgaColor_t;
    
  constant expected: std_logic_vector :=
      "1110010" &
      "1110111" &
      "1110000" &
      "0000000" &
      "0000110" &
      "0000110" &
      "0000000";

BEGIN
  uut: entity work.AnimatedShapes(Behavioral)
    generic map (
      kScreenHeight => kScreenHeight,
      kScreenWidth => kScreenWidth,
      kTestMode => 1
    )
    port map (
      clk => clk,
      start => start,
      frameStart => frameStart,
      moveNext => moveNext,
      pixelColor => pixelColor
    );
      
  clk <= not clk after clk_period/2;

  stim_proc: process
    procedure test(expectedResults: std_logic_vector) is
      variable expectedPixelColor: vgaColor_t;
      variable text: line;
    begin
      report "Testing";
      
      -- pulse start
      start <= '1';
      wait for clk_period;      
      start <= '0';
      
      for i in 0 to kNumFrames-1 loop
        -- pulse frameStart
        frameStart <= '1';
        wait for clk_period;
        frameStart <= '0';
        moveNext <= '0';
        -- we promise the underlying routines that there will be a "few" screen widths of lag
        -- between frameStart and the first moveNext
        wait for 3*kScreenWidth*clk_period;
        
        for i in expectedResults'low to expectedResults'high loop
          if (expectedResults(i) = '1') then
            expectedPixelColor := CreateVgaColor(0, 0, 3);
          else
            expectedPixelColor := CreateVgaColor(0, 0, 0);
          end if;  -- if (expectedResults(i) = '1')
          
          write(text, "index " & natural'image(i)
            & ": expected " & ToString(expectedPixelColor)
            & "; got " & ToString(pixelColor));
          assert (pixelColor = expectedPixelColor) report text.all;
          --writeline(output, text);
          deallocate(text);
          moveNext <= '1';
          wait for clk_period;
        end loop;  -- for i in expectedResults'low to expectedResults'high loop
        moveNext <= '0';
        
        wait for 5*clk_period;
      end loop;  -- for i in 0 to numFrames-1 loop
    end procedure test;
      
  begin
    wait for clk_period*10;
    test(expected);
    report "Test done";
    wait;
  end process;

END;
