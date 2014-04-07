library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Cache is
  generic (
    resultDataSize: positive
  );
  port (
    clk: in std_logic;
    start: in std_logic;
    ready: out std_logic;
    moveNext: in std_logic;
    resultData: out std_logic_vector(0 to resultDataSize-1);
    done: out std_logic;
    
    -- Slave controls, relative to me.
    slaveStart: out std_logic;
    slaveReady: in std_logic;
    slaveMoveNext: out std_logic;
    slaveResultData: in std_logic_vector(0 to resultDataSize-1);
    slaveDone: in std_logic
  );
end Cache;

architecture Behavioral of Cache is
  signal resultData_0, resultData_1: std_logic_vector(0 to resultDataSize-1);
  signal resultDone_0, resultDone_1: std_logic;
  signal spareResultData, spareResultData_1: std_logic_vector(0 to resultDataSize-1);
  signal spareDone, spareDone_1: std_logic;
  signal spareValid, spareValid_1: std_logic;
  
  type state_t is (idle, waitSlaveReady, running);
  signal state, state_1: state_t;
  
begin
  slaveStart <= start;
  
  async: process(state, start,
      resultData_0, resultDone_0,
      spareResultData, spareDone, spareValid,
      slaveReady, slaveResultData, slaveDone, moveNext) is
  begin
    resultData <= resultData_0;
    done <= resultDone_0;
    
    resultData_1 <= resultData_0;
    resultDone_1 <= resultDone_0;
    
    spareResultData_1 <= spareResultData;
    spareDone_1 <= spareDone;
    spareValid_1 <= spareValid;
    
    slaveMoveNext <= '0';
    state_1 <= state;
    
    -- ready logic
    case state is
      when running => ready <= not start;
      when others => ready <= '0';
    end case;
    
    case state is
      when idle =>
        -- nothing

      when waitSlaveReady =>
        if (slaveReady = '1') then
          resultData_1 <= slaveResultData;
          resultDone_1 <= slaveDone;
          slaveMoveNext <= '1';
          spareValid_1 <= '0';
          state_1 <= running;
        end if;  -- if (slaveReady = '1')
        
      when running =>
        -- if moveNext, then populate resultData from either spare or slave.
        if (moveNext = '1') then
          if (spareValid = '1') then
            resultData_1 <= spareResultData;
            resultDone_1 <= spareDone;
          else
            resultData_1 <= slaveResultData;
            resultDone_1 <= slaveDone;
          end if;  -- if (spareValid = '1')
          spareValid_1 <= '0';
        end if;  -- if (moveNext = '1')
        
        -- if spare is not valid (and slave result wasn't used above), then populate it from slave.
        if (spareValid = '0' and moveNext = '0') then
          spareResultData_1 <= slaveResultData;
          spareDone_1 <= slaveDone;
          spareValid_1 <= '1';
        end if;
        
        -- if spareValid=0 then we have consumed the slave result when either moveNext=0 or 1.
        -- This logic could be included in the above clauses, but we want to show explicitly
        -- (in terms of having long logic paths) that slaveMoveNext does not depend on moveNext.
        if (spareValid = '0') then
          slaveMoveNext <= '1';
        end if;  -- if (spareValid = '0')
    end case;
  end process async;

  sync: process(clk) is
  begin
    if (rising_edge(clk)) then
      if (start = '1') then
        state <= waitSlaveReady;
      else
        state <= state_1;
        resultData_0 <= resultData_1;
        resultDone_0 <= resultDone_1;
        spareResultData <= spareResultData_1;
        spareDone <= spareDone_1;
        spareValid <= spareValid_1;
      end if;  -- if (start = '1')
    end if;  --if (rising_edge(clk))
  end process sync;

end Behavioral;
