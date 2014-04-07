-- This module is a little experiment which shortens my combinatorial logic chains somewhat by
-- inserting a "cache" between two modules. The cache adds a cycle of delay to the "startup phase"
-- of my protocol, and makes the pipeline one element longer, but of course still permits values to
-- be produced at a rate of one value per cycle.
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.kCoordWidth;
use work.util.coord_t;
use work.util.point_t;
use work.util.xposAndSegmentWidth_t;

entity CachedArbitraryLine is
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
end CachedArbitraryLine;

architecture Behavioral of CachedArbitraryLine is
  type control_t is record
    start: std_logic;
    ready: std_logic;
    moveNext: std_logic;
    done: std_logic;
  end record control_t;
  signal cacheControl, slaveControl: control_t;
  
  constant kResultDataSize: positive := point.y'length + point.x'length;
  
  signal cacheResultData, slaveResultData: std_logic_vector(0 to kResultDataSize-1);
  
  signal slaveFirst, slaveLast, slavePoint: point_t;

begin
  line: entity work.ArbitraryLine
    port map (
      clk => clk,
      first => slaveFirst,
      last => slaveLast,
      start => slaveControl.start,
      ready => slaveControl.ready,
      moveNext => slaveControl.moveNext,
      point => slavePoint,
      done => slaveControl.done
    );

  cache: entity work.Cache(Behavioral)
  generic map(
    resultDataSize => kResultDataSize
  )
  port map(
    clk => clk,
    
    start => cacheControl.start,
    ready => cacheControl.ready,
    moveNext => cacheControl.moveNext,
    resultData => cacheResultData,
    done => cacheControl.done,
    
    slaveStart => slaveControl.start,
    slaveReady => slaveControl.ready,
    slaveMoveNext => slaveControl.moveNext,
    slaveResultData => slaveResultData,
    slaveDone => slaveControl.done
  );
  
  async: process(start, moveNext, cacheControl, cacheResultData, first, last, slavePoint) is
    variable temp: std_logic_vector(0 to kResultDataSize-1);
    variable index: natural;

    procedure Pack(variable buff: inout std_logic_vector;
        variable index: inout natural;
        data: in std_logic_vector) is
    begin
      buff(index to index+data'length-1) := data;
      index := index + data'length;
    end procedure Pack;
    
    procedure Unpack(variable buff: inout std_logic_vector;
        variable index: inout natural;
        variable data: out std_logic_vector) is
    begin
      data := buff(index to index+data'length-1);
      index := index + data'length;
    end procedure Unpack;
    
    variable hate: std_logic_vector(kCoordWidth-1 downto 0);

  begin
    -- wire up cacheControl to my port
    cacheControl.start <= start;
    cacheControl.moveNext <= moveNext;
    ready <= cacheControl.ready;
    done <= cacheControl.done;
    
    -- wire up first and last
    slaveFirst <= first;
    slaveLast <= last;
    
    -- pack line's result (slavePoint) into slaveResultData (grrr... where are my generic types).
    temp := (others => '0');
    index := 0;
    Pack(temp, index, std_logic_vector(slavePoint.y));
    Pack(temp, index, std_logic_vector(slavePoint.x));
    slaveResultData <= temp;
    assert(index = kResultDataSize) report natural'image(index);
    
    -- unpack cacheResult to my port
    temp := cacheResultData;
    index := 0;
    Unpack(temp, index, hate);
    point.y <= unsigned(hate);
    Unpack(temp, index, hate);
    point.x <= unsigned(hate);
    assert(index = kResultDataSize) report natural'image(index);
  end process async;

end Behavioral;
