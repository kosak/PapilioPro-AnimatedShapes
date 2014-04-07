library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.coord_t;
use work.util.kCoordWidth;
use work.util.CreatePoint;
use work.util.point_t;
use work.util.ToString;
use work.util.vgaColor_t;

-- Implements the ScanSequence interface.
entity Rectangle is
  generic (kScreenWidth: positive);
  port (
    clk: in std_logic;
    -- Setup arguments
    origin: in point_t;
    size: in point_t;
    fgColor: in vgaColor_t;
    
    -- Control arguments.
    start: in std_logic;
    moveNext: in std_logic;
    
    -- Control out.
    ready: out std_logic;
    
    -- Data out.
    pixelActive: out std_logic;
    pixelColor: out vgaColor_t
  );
end Rectangle;

architecture Behavioral of Rectangle is
  -- Latched input arguments.
  signal upperLeft, lowerRightLimit: point_t := CreatePoint(0, 0);
  signal latchedFgColor: vgaColor_t;
  
  -- Cursor
  signal cursor, cursor_1: point_t := CreatePoint(0, 0);

begin
  combinatorial: process(start, moveNext, cursor, upperLeft, lowerRightLimit, latchedFgColor)
  begin
    ready <= not start;
    pixelActive <= '0';
    pixelColor <= latchedFgColor;
    
    if (cursor.y >= upperLeft.y and
        cursor.y < lowerRightLimit.y and
        cursor.x >= upperLeft.x and
        cursor.x < lowerRightLimit.x) then
      pixelActive <= '1';
    end if;
    
    cursor_1 <= cursor;  -- Pessimistically assume that the cursor doesn't move.
    if (moveNext = '1') then
      cursor_1.x <= cursor.x + 1;
      if (cursor.x = kScreenWidth-1) then
        cursor_1.x <= to_unsigned(0, cursor_1.x'length);
        cursor_1.y <= cursor.y + 1;  -- Not going to worry about y wrapping.
      end if;
    end if;
  end process combinatorial;
  
  sync: process(clk)
  begin
    if (rising_edge(clk)) then
      if (start = '1') then
        upperLeft <= origin;
        lowerRightLimit.y <= origin.y + size.y;
        lowerRightLimit.x <= origin.x + size.x;
        latchedFgColor <= fgColor;
        cursor.y <= to_unsigned(0, cursor.y'length);
        cursor.x <= to_unsigned(0, cursor.x'length);
      else
        cursor <= cursor_1;
      end if;  -- if (start = '1') then
    end if;  -- if (rising_edge(clk)) then
  end process sync;

end Behavioral;
