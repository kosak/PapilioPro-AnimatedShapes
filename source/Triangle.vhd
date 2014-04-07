library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.point_t;
use work.util.point_t_vector;
use work.util.vgaColor_t;

entity Triangle is
  generic (kScreenHeight: positive; kScreenWidth: positive);
  port (
    clk: in std_logic;
    -- Setup arguments.
    vertices: in point_t_vector(0 to 2);
    fgColor: in vgaColor_t;

    -- Control path.
    start: in std_logic;
    moveNext: in std_logic;

    -- Control out.
    ready: out std_logic;

    -- Data out.
    pixelActive: out std_logic;
    pixelColor: out vgaColor_t
  );
end Triangle;

architecture Behavioral of Triangle is
  type pa2ssInfo_t is record
    start: std_logic;
    ready: std_logic;
    moveNext: std_logic;
    pixelActive: std_logic;
  end record;
  signal pa2ssInfo: pa2ssInfo_t;
  
  signal latched_vertices: point_t_vector(0 to 2);
  signal latched_fgColor: vgaColor_t;
  signal lineStarts: std_logic_vector(0 to 2);
  signal lineReadys: std_logic_vector(0 to 2);
  signal lineMoveNexts: std_logic_vector(0 to 2);
  signal linePoints: point_t_vector(0 to 2);
  signal lineDones: std_logic_vector(0 to 2);

begin
  pa2ss: entity work.PointArraysToScanSequence
    generic map (
      numComponents => 3,
      kScreenHeight => kScreenHeight,
      kScreenWidth => kScreenWidth
    )
    port map (
      clk => clk,
      start => pa2ssInfo.start,
      ready => pa2ssInfo.ready,
      moveNext => pa2ssInfo.moveNext,
      pixelActive => pa2ssInfo.pixelActive,
      slaveStarts => lineStarts,
      slaveReadys => lineReadys,
      slaveMoveNexts => lineMoveNexts,
      slavePoints => linePoints,
      slaveDones => lineDones
    );

  generate_lines: for i in 0 to 2 generate
    lineX: entity work.CachedArbitraryLine
      port map (
        clk => clk,
        first => latched_vertices(i),
        last => latched_vertices((i+1) mod 3),
        start => lineStarts(i),
        ready => lineReadys(i),
        moveNext => lineMoveNexts(i),
        point => linePoints(i),
        done => lineDones(i)
      );
  end generate generate_lines;
  
  combinatorial: process(moveNext, pa2ssInfo, latched_fgColor) is
  begin
    pa2ssInfo.moveNext <= moveNext;
    
    ready <= pa2ssInfo.ready;
    pixelActive <= pa2ssInfo.pixelActive;
    
    pixelColor <= latched_fgColor;
  end process combinatorial;
  
  sync: process(clk) is
  begin
    if (rising_edge(clk)) then
      if (start = '1') then
        latched_vertices <= vertices;
        latched_fgColor <= fgColor;
        pa2ssInfo.start <= '1';
      else
        pa2ssInfo.start <= '0';
        -- As an aid to debugging, poison latched_vertices as soon as pa2ss is ready (it shouldn't
        -- depend on them after that).
        if (pa2ssInfo.ready = '1') then
          latched_vertices <= (others => (y => (others => 'U'), x => (others => 'U')));
        end if;
      end if;  -- if (start = '1')
    end if;  --if (rising_edge(clk))
  end process sync;

end Behavioral;
