library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.vgaColor_t;
use work.util.vgaColor_t_vector;

entity ScanSequenceCompositor is
  generic (numComponents: positive;
      kScreenHeight: positive;
      kScreenWidth: positive);
  port (
    clk: in std_logic;
    -- Control path.
    start: in std_logic;
    moveNext: in std_logic;

    -- outputs
    pixelActive: out std_logic;
    pixelColor: out vgaColor_t;
    collisions: out std_logic_vector(0 to numComponents-1);
    
    -- Slave control path.
    slaveStarts: out std_logic_vector(0 to numComponents-1);
    slaveReadys: in std_logic_vector(0 to numComponents-1);
    slaveMoveNexts: out std_logic_vector(0 to numComponents-1);
    
    -- Slave outputs (inputs relative to this module).
    slavePixelActives: in std_logic_vector(0 to numComponents-1);
    slavePixelColors: in vgaColor_t_vector(0 to numComponents-1)
  );

end ScanSequenceCompositor;

architecture Behavioral of ScanSequenceCompositor is

begin
  combinatorial: process(start, moveNext, slavePixelActives, slavePixelColors)
    variable atLeastOneSlaveAssertsPixel: std_logic;
  begin
    for i in 0 to numComponents-1 loop
      slaveStarts(i) <= start;
      slaveMoveNexts(i) <= moveNext;
    end loop;
    
    pixelActive <= '0';
    pixelColor <= (r => (others => '0'), g => (others => '0'), b => (others => '0'));
    atLeastOneSlaveAssertsPixel := '0';
    collisions <= (others => '0');
    for i in 0 to numComponents-1 loop
      if (slavePixelActives(i) = '1') then
        if (atLeastOneSlaveAssertsPixel = '1') then
          collisions <= slavePixelActives;
        end if;
        atLeastOneSlaveAssertsPixel := '1';
        pixelActive <= '1';
        pixelColor <= slavePixelColors(i);
      end if; -- if (slavePixelActives(i) = '1')
    end loop;
  end process combinatorial;
end Behavioral;
