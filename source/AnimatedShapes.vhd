library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.CreatePoint;
use work.util.CreateRectangle;
use work.util.CreateVgaColor;
use work.util.kCoordWidth;
use work.util.point_t;
use work.util.point_t_vector;
use work.util.rect_t_vector;
use work.util.vgaColor_t;
use work.util.vgaColor_t_vector;

entity AnimatedShapes is
  generic (
    kScreenHeight: positive;
    kScreenWidth: positive;
    kTestMode: natural
  );
  port (
    clk: in std_logic;
    -- Control path.
    start: in std_logic;
    frameStart: in std_logic;
    moveNext: in std_logic;

    -- outputs
    pixelColor: out vgaColor_t
  );
end AnimatedShapes;

architecture Behavioral of AnimatedShapes is
  constant numRectangles: positive := 2;
  constant numTriangles: positive := 2;
  constant numComponents: positive := numRectangles + numTriangles;
  
  type compositorInfo_t is record
    start: std_logic;
    moveNext: std_logic;

    pixelActive: std_logic;
    pixelColor: vgaColor_t;
    collisions: std_logic_vector(0 to numComponents-1);
  end record;
  signal compositorInfo: compositorInfo_t;
    
  type slaveInfo_t is record
    fgColors: vgaColor_t_vector(0 to numComponents-1);
    starts: std_logic_vector(0 to numComponents-1);
    readys: std_logic_vector(0 to numComponents-1);
    moveNexts: std_logic_vector(0 to numComponents-1);
    pixelActives: std_logic_vector(0 to numComponents-1);
    pixelColors: vgaColor_t_vector(0 to numComponents-1);
  end record;
  
  signal slaveInfo: slaveInfo_t;
    
  signal rectOrigins, rectOrigins_1: point_t_vector(0 to numRectangles-1);
  signal rectSizes: point_t_vector(0 to numRectangles-1);
  signal rectVelocities, rectVelocities_1: point_t_vector(0 to numRectangles-1);
  
  subtype triangleVertices_t is point_t_vector(0 to 2);
  type triangleVertices_t_vector is array(natural range<>) of triangleVertices_t;
  signal triangleVertices, triangleVertices_1: triangleVertices_t_vector(0 to numTriangles-1);
  signal triangleVelocities, triangleVelocities_1: triangleVertices_t_vector(0 to numTriangles-1);
  
  type state_t is (idle, updateCoords, running);
  signal state, state_1: state_t := idle;
  
  signal collisionsInThisFrame, collisionsInThisFrame_1: std_logic_vector(0 to numComponents-1);
  signal fgColors, fgColors_1: vgaColor_t_vector(0 to numComponents-1);
  
  function CreateTriangleVertices(p0: point_t; p1: point_t; p2: point_t) return triangleVertices_t is
  begin
    return (p0, p1, p2);
  end function CreateTriangleVertices;
  
  constant kForegroundPixel: vgaColor_t := CreateVgaColor(7, 7, 0);
  constant kCollisionPixel: vgaColor_t := CreateVgaColor(7, 0, 0);
  
  constant kRectangles: rect_t_vector(0 to numRectangles-1) := (
    CreateRectangle(150, 125, 100, 25),
    CreateRectangle(100, 100, 100, 100)
  );
  constant kTriangleVertices: triangleVertices_t_vector(0 to numTriangles-1) := (
    CreateTriangleVertices(CreatePoint(0, 200), CreatePoint(125, 300), CreatePoint(75, 100)),
    CreateTriangleVertices(CreatePoint(50, 50), CreatePoint(60,60), CreatePoint(60, 40))
  );
  
-- xxx..x.
-- xxx.xxx
-- xxx....
-- .......
-- ....xx.
-- .x..xx.
-- xxx....

  constant kTestRectangles: rect_t_vector(0 to numRectangles-1) := (
    CreateRectangle(0, 0, 3, 3),
    CreateRectangle(4, 4, 2, 2)
  );
  constant kTestTriangleVertices: triangleVertices_t_vector(0 to numTriangles-1) := (
    CreateTriangleVertices(CreatePoint(0, 5), CreatePoint(1, 6), CreatePoint(1, 4)),
    CreateTriangleVertices(CreatePoint(5, 1), CreatePoint(6, 2), CreatePoint(6, 0))
  );

begin
  generate_rects: for i in 0 to numRectangles-1 generate
    rectX: entity work.Rectangle
      generic map (
        kScreenWidth => kScreenWidth
      )
      port map (
        clk => clk,
        origin => rectOrigins(i),
        size => rectSizes(i),
        fgColor => slaveInfo.fgColors(i),
        start => slaveInfo.starts(i),
        ready => slaveInfo.readys(i),
        pixelActive => slaveInfo.pixelActives(i),
        pixelColor => slaveInfo.pixelColors(i),
        moveNext => slaveInfo.moveNexts(i)
      );
  end generate generate_rects;
  
  generate_triangles: for i in 0 to numTriangles-1 generate
    triX: entity work.Triangle
      generic map (
        kScreenHeight => kScreenHeight,
        kScreenWidth => kScreenWidth
      )
      port map (
        clk => clk,
        vertices => triangleVertices(i),
        fgColor => slaveInfo.fgColors(numRectangles+i),
        start => slaveInfo.starts(numRectangles+i),
        moveNext => slaveInfo.moveNexts(numRectangles+i),
        ready => slaveInfo.readys(numRectangles+i),
        pixelActive => slaveInfo.pixelActives(numRectangles+i),
        pixelColor => slaveInfo.pixelColors(numRectangles+i)
      );
  end generate generate_triangles;
  
  compositor: entity work.ScanSequenceCompositor
    generic map (
      numComponents => numComponents,
      kScreenHeight => kScreenHeight,
      kScreenWidth => kScreenWidth
    )
    port map (
      clk => clk,
      start => compositorInfo.start,
      moveNext => compositorInfo.moveNext,

      -- outputs
      pixelActive => compositorInfo.pixelActive,
      pixelColor => compositorInfo.pixelColor,
      collisions => compositorInfo.collisions,
      
      -- Slave control path.
      slaveStarts => slaveInfo.starts,
      slaveReadys => slaveInfo.readys,
      slaveMoveNexts => slaveInfo.moveNexts,
      
      -- Slave outputs (inputs relative to this module).
      slavePixelActives => slaveInfo.pixelActives,
      slavePixelColors => slaveInfo.pixelColors
    );
    
  combinatorial: process(frameStart, moveNext, state, slaveInfo, compositorInfo,
      collisionsInThisFrame, fgColors,
      rectOrigins, rectSizes, rectVelocities,
      triangleVertices, triangleVelocities)
    variable offYEdge, offXEdge: std_logic;
    variable anyOffYEdge, anyOffXEdge: std_logic;
    variable rectangleTemp: point_t_vector(0 to 1);
    variable triangleTemp: point_t;
    
    variable rectPoints: point_t_vector(0 to 1);
    
    procedure UpdateVertex(
        vertex: point_t;
        velocity: point_t;
        variable result: out point_t;
        variable offYEdge: out std_logic;
        variable offXEdge: out std_logic) is
      variable temp: point_t;
    begin
      temp.y := vertex.y + velocity.y;
      temp.x := vertex.x + velocity.x;
      result := temp;
      
      offYEdge := '0';
      offXEdge := '0';
      if (temp.y >= kScreenHeight) then
        offYEdge := '1';
      end if;
      if (temp.x >= kScreenWidth) then
        offXEdge := '1';
      end if;
    end procedure UpdateVertex;
    
    function TwosComplement(value: unsigned) return unsigned is
    begin
      return unsigned(std_logic_vector(-signed(std_logic_vector(value))));
    end function TwosComplement;
  begin
    compositorInfo.start <= '0';

    pixelColor <= compositorInfo.pixelColor;
    compositorInfo.moveNext <= moveNext;
    
    collisionsInThisFrame_1 <= collisionsInThisFrame;
    slaveInfo.fgColors <= fgColors;
    fgColors_1 <= fgColors;
    
    triangleVertices_1 <= triangleVertices;
    triangleVelocities_1 <= triangleVelocities;
    
    rectOrigins_1 <= rectOrigins;
    rectVelocities_1 <= rectVelocities;
    
    state_1 <= state;  -- Default is to loop.
    case state is
      when idle =>
        -- do nothing.
        
      when updateCoords =>
        -- For each rectangle
        --   Extract extreme points of rectangle (upper left and lower right).
        --   Use our generic update algorithm to bump those two points.
        --   If any exceeds the boundaries, then invert velocity and roll back.
        for rect in 0 to numRectangles-1 loop
          rectPoints(0) := rectOrigins(rect);
          
          rectPoints(1).y := rectOrigins(rect).y + rectSizes(rect).y;
          rectPoints(1).x := rectOrigins(rect).x + rectSizes(rect).x;
          
          anyOffYEdge := '0';
          anyOffXEdge := '0';
          for vtx in 0 to 1 loop
            UpdateVertex(
              rectPoints(vtx),
              rectVelocities(rect),
              rectangleTemp(vtx), offYEdge, offXEdge);
            anyOffYEdge := anyOffYEdge or offYEdge;
            anyOffXEdge := anyOffXEdge or offXEdge;
          end loop;
         
          if (anyOffYEdge = '1') then
            rectVelocities_1(rect).y <= TwosComplement(rectVelocities(rect).y);
          end if;

          if (anyOffXEdge = '1') then
            rectVelocities_1(rect).x <= TwosComplement(rectVelocities(rect).x);
          end if;
          
          if (anyOffYEdge = '0' and anyOffXEdge = '0') then
            rectOrigins_1(rect) <= rectangleTemp(0);  -- commit
          end if;
        end loop;

        -- for each triangle
          -- for each vertex
            -- new point = oldpoint + velocity
          -- if any new point violates x then invert x velocity
          -- and if any new point violates y then invert y velocity
          -- but otherwise commit the changes to this triangle
        for tri in 0 to numTriangles-1 loop
          for vtx in 0 to 2 loop
            UpdateVertex(
                triangleVertices(tri)(vtx),
                triangleVelocities(tri)(vtx),
                triangleTemp, offYEdge, offXEdge);
          
            if (offYEdge = '1') then
              triangleVelocities_1(tri)(vtx).y <= TwosComplement(triangleVelocities(tri)(vtx).y);
            end if;

            if (offXEdge = '1') then
              triangleVelocities_1(tri)(vtx).x <= TwosComplement(triangleVelocities(tri)(vtx).x);
            end if;

            if (offYEdge = '0' and offXEdge = '0') then
              triangleVertices_1(tri)(vtx) <= triangleTemp;  -- commit
            end if;
          end loop;
        end loop;
        
        for i in 0 to numComponents-1 loop
          if (collisionsInThisFrame(i) = '1') then
            fgColors_1(i) <= kCollisionPixel;
          else
            fgColors_1(i) <= kForegroundPixel;
          end if;  -- if (collisionsInThisFrame(i) == '1')
        end loop;
        
        collisionsInThisFrame_1 <= (others => '0');
        compositorInfo.start <= '1';
        state_1 <= running;
        
      when running =>
        for i in 0 to numComponents-1 loop
          collisionsInThisFrame_1(i) <= collisionsInThisFrame(i) or compositorInfo.collisions(i);
        end loop;
    end case;
  end process combinatorial;
  
  sync: process(clk)
    procedure DoStart is
    begin
      if (kTestMode = 0) then
        for i in 0 to numRectangles-1 loop
          rectOrigins(i) <= kRectangles(i).origin;
          rectSizes(i) <= kRectangles(i).size;
        end loop;
        triangleVertices <= kTriangleVertices;
      else
        for i in 0 to numRectangles-1 loop
          rectOrigins(i) <= kTestRectangles(i).origin;
          rectSizes(i) <= kTestRectangles(i).size;
        end loop;
        triangleVertices <= kTestTriangleVertices;
      end if;  -- if (kTestMode = '0')
      for i in 0 to numRectangles-1 loop
        rectVelocities(i).y <= to_unsigned(2+i, rectVelocities(i).y'length);
        rectVelocities(i).x <= to_unsigned(3+i, rectVelocities(i).x'length);
      end loop;
      
      -- In triangle 0, all 3 vertices have the same velocity, namely (1,2)
      for vtx in 0 to 2 loop
        triangleVelocities(0)(vtx).y <= to_unsigned(1, triangleVelocities(0)(vtx).y'length);
        triangleVelocities(0)(vtx).x <= to_unsigned(2, triangleVelocities(0)(vtx).x'length);
      end loop;
      
      -- The vertices of the other triangles are determined by (1+i+vtx,2+i+vtx).
      for i in 1 to numTriangles-1 loop
        for vtx in 0 to 2 loop
          triangleVelocities(i)(vtx).y <= to_unsigned(1+i+vtx, triangleVelocities(i)(vtx).y'length);
          triangleVelocities(i)(vtx).x <= to_unsigned(2+i+vtx, triangleVelocities(i)(vtx).x'length);
        end loop;
      end loop;
    end procedure DoStart;

  begin
    if (rising_edge(clk)) then
      if (start = '1') then
        DoStart;
        state <= idle;
      elsif (frameStart = '1') then
        state <= updateCoords;
      else
        triangleVertices <= triangleVertices_1;
        triangleVelocities <= triangleVelocities_1;
        rectOrigins <= rectOrigins_1;
        rectVelocities <= rectVelocities_1;
        collisionsInThisFrame <= collisionsInThisFrame_1;
        fgColors <= fgColors_1;
        state <= state_1;
      end if;  -- if (start = '1')
    end if;  --if (rising_edge(clk))
  end process sync;

end Behavioral;
