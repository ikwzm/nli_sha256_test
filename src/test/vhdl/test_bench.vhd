-----------------------------------------------------------------------------------
--!     @file    test_bench.vhd
--!     @brief   Test Bench for SHA256_Server
--!     @version 0.1.0
--!     @date    2017/11/29
--!     @author  Ichiro Kawazome <ichiro_k@ca2.so-net.ne.jp>
-----------------------------------------------------------------------------------
--
--      Copyright (C) 2017 Ichiro Kawazome
--      All rights reserved.
--
--      Redistribution and use in source and binary forms, with or without
--      modification, are permitted provided that the following conditions
--      are met:
--
--        1. Redistributions of source code must retain the above copyright
--           notice, this list of conditions and the following disclaimer.
--
--        2. Redistributions in binary form must reproduce the above copyright
--           notice, this list of conditions and the following disclaimer in
--           the documentation and/or other materials provided with the
--           distribution.
--
--      THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
--      "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
--      LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
--      A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
--      OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
--      SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
--      LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
--      DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
--      THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
--      (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
--      OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--
-----------------------------------------------------------------------------------
library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     std.textio.all;
library DUMMY_PLUG;
use     DUMMY_PLUG.AXI4_TYPES.all;
use     DUMMY_PLUG.AXI4_MODELS.AXI4_STREAM_MASTER_PLAYER;
use     DUMMY_PLUG.AXI4_MODELS.AXI4_STREAM_SLAVE_PLAYER;
use     DUMMY_PLUG.AXI4_MODELS.AXI4_SLAVE_PLAYER;
use     DUMMY_PLUG.SYNC.all;
use     DUMMY_PLUG.CORE.MARCHAL;
use     DUMMY_PLUG.CORE.REPORT_STATUS_TYPE;
use     DUMMY_PLUG.CORE.REPORT_STATUS_VECTOR;
use     DUMMY_PLUG.CORE.MARGE_REPORT_STATUS;
-----------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------
entity  TEST_BENCH is
    generic (
        NAME            : STRING := "TEST";
        SCENARIO_FILE   : STRING := "test.snr"
    );
end     TEST_BENCH;
-----------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------
architecture MODEL of TEST_BENCH is
    -------------------------------------------------------------------------------
    -- 
    -------------------------------------------------------------------------------
    constant CLOCK_PERIOD    : time    := 10 ns;
    constant DELAY           : time    :=  1 ns;
    constant MATCH_PHASE     : integer :=  8;
    constant I_BYTES         : integer :=  4;
    constant I_WIDTH         : AXI4_STREAM_SIGNAL_WIDTH_TYPE := (
                                 ID    => 4,
                                 USER  => 4,
                                 DEST  => 4,
                                 DATA  => 8*I_BYTES);
    constant O_BYTES         : integer :=  4;
    constant O_WIDTH         : AXI4_STREAM_SIGNAL_WIDTH_TYPE := (
                                 ID    => 4,
                                 USER  => 4,
                                 DEST  => 4,
                                 DATA  => 8*O_BYTES);
    constant M_WIDTH         : AXI4_SIGNAL_WIDTH_TYPE := (
                                 ID    => 4,
                                 AWADDR=> 32,
                                 ARADDR=> 32,
                                 ALEN  => 8,
                                 ALOCK => 1,
                                 WDATA => 32,
                                 RDATA => 32,
                                 ARUSER=> 1,
                                 AWUSER=> 1,
                                 WUSER => 1,
                                 RUSER => 1,
                                 BUSER => 1);
    constant SYNC_WIDTH      : integer :=  2;
    constant GPO_WIDTH       : integer :=  8;
    constant GPI_WIDTH       : integer :=  GPO_WIDTH;
    -------------------------------------------------------------------------------
    -- 
    -------------------------------------------------------------------------------
    signal   ARESETn         : std_logic;
    signal   RESET           : std_logic;
    signal   CLOCK           : std_logic;
    -------------------------------------------------------------------------------
    -- 
    -------------------------------------------------------------------------------
    signal   SYNC            : SYNC_SIG_VECTOR (SYNC_WIDTH     -1 downto 0);
    -------------------------------------------------------------------------------
    -- 
    -------------------------------------------------------------------------------
    signal   I_TDATA         : std_logic_vector(I_WIDTH.DATA   -1 downto 0);
    signal   I_TSTRB         : std_logic_vector(I_WIDTH.DATA/8 -1 downto 0);
    signal   I_TKEEP         : std_logic_vector(I_WIDTH.DATA/8 -1 downto 0);
    signal   I_TLAST         : std_logic;
    signal   I_TVALID        : std_logic;
    signal   I_TREADY        : std_logic;
    -------------------------------------------------------------------------------
    -- 
    -------------------------------------------------------------------------------
    signal   O_TDATA         : std_logic_vector(O_WIDTH.DATA   -1 downto 0);
    signal   O_TSTRB         : std_logic_vector(O_WIDTH.DATA/8 -1 downto 0);
    signal   O_TKEEP         : std_logic_vector(O_WIDTH.DATA/8 -1 downto 0) := (others => '1');
    signal   O_TUSER         : std_logic_vector(O_WIDTH.USER   -1 downto 0) := (others => '0');
    constant O_TDEST         : std_logic_vector(O_WIDTH.DEST   -1 downto 0) := (others => '0');
    constant O_TID           : std_logic_vector(O_WIDTH.ID     -1 downto 0) := (others => '0');
    signal   O_TLAST         : std_logic;
    signal   O_TVALID        : std_logic;
    signal   O_TREADY        : std_logic;
    ------------------------------------------------------------------------------
    -- 
    ------------------------------------------------------------------------------
    signal   M_ARADDR        : std_logic_vector(M_WIDTH.ARADDR -1 downto 0);
    signal   M_ARLEN         : std_logic_vector(M_WIDTH.ALEN   -1 downto 0);
    signal   M_ARSIZE        : AXI4_ASIZE_TYPE;
    signal   M_ARBURST       : AXI4_ABURST_TYPE;
    signal   M_ARCACHE       : AXI4_ACACHE_TYPE;
    constant M_ARLOCK        : std_logic_vector(M_WIDTH.ALOCK  -1 downto 0) := (others => '0');
    constant M_ARPROT        : AXI4_APROT_TYPE   := (others => '0');
    constant M_ARQOS         : AXI4_AQOS_TYPE    := (others => '0');
    constant M_ARREGION      : AXI4_AREGION_TYPE := (others => '0');
    constant M_ARUSER        : std_logic_vector(M_WIDTH.ARUSER -1 downto 0) := (others => '0');
    constant M_ARID          : std_logic_vector(M_WIDTH.ID     -1 downto 0) := (others => '0');
    signal   M_ARVALID       : std_logic;
    signal   M_ARREADY       : std_logic;
    signal   M_RVALID        : std_logic;
    signal   M_RLAST         : std_logic;
    signal   M_RDATA         : std_logic_vector(M_WIDTH.RDATA  -1 downto 0);
    signal   M_RRESP         : AXI4_RESP_TYPE;
    signal   M_RUSER         : std_logic_vector(M_WIDTH.RUSER  -1 downto 0);
    signal   M_RID           : std_logic_vector(M_WIDTH.ID     -1 downto 0);
    signal   M_RREADY        : std_logic;
    signal   M_AWADDR        : std_logic_vector(M_WIDTH.AWADDR -1 downto 0);
    signal   M_AWLEN         : std_logic_vector(M_WIDTH.ALEN   -1 downto 0);
    signal   M_AWSIZE        : AXI4_ASIZE_TYPE;
    signal   M_AWBURST       : AXI4_ABURST_TYPE;
    signal   M_AWCACHE       : AXI4_ACACHE_TYPE;
    constant M_AWLOCK        : std_logic_vector(M_WIDTH.ALOCK  -1 downto 0) := (others => '0');
    constant M_AWPROT        : AXI4_APROT_TYPE   := (others => '0');
    constant M_AWQOS         : AXI4_AQOS_TYPE    := (others => '0');
    constant M_AWREGION      : AXI4_AREGION_TYPE := (others => '0');
    constant M_AWUSER        : std_logic_vector(M_WIDTH.AWUSER -1 downto 0) := (others => '0');
    constant M_AWID          : std_logic_vector(M_WIDTH.ID     -1 downto 0) := (others => '0');
    signal   M_AWVALID       : std_logic;
    signal   M_AWREADY       : std_logic;
    signal   M_WLAST         : std_logic;
    signal   M_WDATA         : std_logic_vector(M_WIDTH.WDATA  -1 downto 0);
    signal   M_WSTRB         : std_logic_vector(M_WIDTH.WDATA/8-1 downto 0);
    signal   M_WUSER         : std_logic_vector(M_WIDTH.WUSER  -1 downto 0);
    signal   M_WID           : std_logic_vector(M_WIDTH.ID     -1 downto 0);
    signal   M_WVALID        : std_logic;
    signal   M_WREADY        : std_logic;
    signal   M_BRESP         : AXI4_RESP_TYPE;
    signal   M_BUSER         : std_logic_vector(M_WIDTH.BUSER  -1 downto 0);
    signal   M_BID           : std_logic_vector(M_WIDTH.ID     -1 downto 0);
    signal   M_BVALID        : std_logic;
    signal   M_BREADY        : std_logic;
    -------------------------------------------------------------------------------
    -- 
    -------------------------------------------------------------------------------
    signal   I_GPI           : std_logic_vector(GPI_WIDTH      -1 downto 0);
    signal   I_GPO           : std_logic_vector(GPO_WIDTH      -1 downto 0);
    signal   O_GPI           : std_logic_vector(GPI_WIDTH      -1 downto 0);
    signal   O_GPO           : std_logic_vector(GPO_WIDTH      -1 downto 0);
    signal   M_GPI           : std_logic_vector(GPI_WIDTH      -1 downto 0);
    signal   M_GPO           : std_logic_vector(GPO_WIDTH      -1 downto 0);
    -------------------------------------------------------------------------------
    -- 
    -------------------------------------------------------------------------------
    signal   N_REPORT        : REPORT_STATUS_TYPE;
    signal   I_REPORT        : REPORT_STATUS_TYPE;
    signal   O_REPORT        : REPORT_STATUS_TYPE;
    signal   M_REPORT        : REPORT_STATUS_TYPE;
    signal   N_FINISH        : std_logic;
    signal   I_FINISH        : std_logic;
    signal   O_FINISH        : std_logic;
    signal   M_FINISH        : std_logic;
    -------------------------------------------------------------------------------
    --
    -------------------------------------------------------------------------------
    component SHA256_Server
        generic(
            I_BYTES              : integer := 1;
            O_BYTES              : integer := 1
        );
        port(
            CLK                  : in  std_logic;
            ARESETn              : in  std_logic;
            I_TDATA              : in  std_logic_vector(8*I_BYTES-1 downto 0);
            I_TKEEP              : in  std_logic_vector(  I_BYTES-1 downto 0);
            I_TLAST              : in  std_logic;
            I_TVALID             : in  std_logic;
            I_TREADY             : out std_logic;
            O_TDATA              : out std_logic_vector(8*O_BYTES-1 downto 0);
            O_TKEEP              : out std_logic_vector(  O_BYTES-1 downto 0);
            O_TLAST              : out std_logic;
            O_TVALID             : out std_logic;
            O_TREADY             : in  std_logic;
            BUF_ARADDR           : out std_logic_vector(31 downto 0);
            BUF_ARVALID          : out std_logic;
            BUF_ARREADY          : in  std_logic;
            BUF_ARLEN            : out std_logic_vector( 7 downto 0);
            BUF_ARBURST          : out std_logic_vector( 1 downto 0);
            BUF_ARSIZE           : out std_logic_vector( 2 downto 0);
            BUF_ARCACHE          : out std_logic_vector( 3 downto 0);
            BUF_RVALID           : in  std_logic;
            BUF_RDATA            : in  std_logic_vector(31 downto 0);
            BUF_RREADY           : out std_logic;
            BUF_RLAST            : in  std_logic;
            BUF_AWADDR           : out std_logic_vector(31 downto 0);
            BUF_AWVALID          : out std_logic;
            BUF_AWREADY          : in  std_logic;
            BUF_AWLEN            : out std_logic_vector( 7 downto 0);
            BUF_AWSIZE           : out std_logic_vector( 2 downto 0);
            BUF_AWCACHE          : out std_logic_vector( 3 downto 0);
            BUF_AWBURST          : out std_logic_vector( 1 downto 0);
            BUF_WVALID           : out std_logic;
            BUF_WREADY           : in  std_logic;
            BUF_WDATA            : out std_logic_vector(31 downto 0);
            BUF_WLAST            : out std_logic;
            BUF_BVALID           : in  std_logic;
            BUF_BREADY           : out std_logic;
            BUF_BRESP            : in  std_logic_vector( 1 downto 0)
        );
    end  component;
begin
    -------------------------------------------------------------------------------
    -- 
    -------------------------------------------------------------------------------
    N: MARCHAL
        generic map(
            SCENARIO_FILE   => SCENARIO_FILE,
            NAME            => "MARCHAL",
            SYNC_PLUG_NUM   => 1,
            SYNC_WIDTH      => SYNC_WIDTH,
            FINISH_ABORT    => FALSE
        )
        port map(
            CLK             => CLOCK           , -- In  :
            RESET           => RESET           , -- In  :
            SYNC(0)         => SYNC(0)         , -- I/O :
            SYNC(1)         => SYNC(1)         , -- I/O :
            REPORT_STATUS   => N_REPORT        , -- Out :
            FINISH          => N_FINISH          -- Out :
        );
    -------------------------------------------------------------------------------
    -- 
    -------------------------------------------------------------------------------
    I: AXI4_STREAM_MASTER_PLAYER                 -- 
        generic map (                            -- 
            SCENARIO_FILE   => SCENARIO_FILE   , --
            NAME            => "I"             , --
            OUTPUT_DELAY    => DELAY           , --
            SYNC_PLUG_NUM   => 2               , --
            WIDTH           => I_WIDTH         , --
            SYNC_WIDTH      => SYNC_WIDTH      , --
            GPI_WIDTH       => GPI_WIDTH       , --
            GPO_WIDTH       => GPO_WIDTH       , --
            FINISH_ABORT    => FALSE             --
        )                                        -- 
        port map (                               -- 
            ACLK            => CLOCK           , -- In  :
            ARESETn         => ARESETn         , -- In  :
            TDATA           => I_TDATA         , -- Out :
            TSTRB           => open            , -- Out :
            TKEEP           => I_TKEEP         , -- Out :
            TUSER           => open            , -- Out :
            TDEST           => open            , -- Out :
            TID             => open            , -- Out :
            TLAST           => I_TLAST         , -- Out :
            TVALID          => I_TVALID        , -- Out :
            TREADY          => I_TREADY        , -- In  :
            SYNC            => SYNC            , -- I/O :
            GPI             => I_GPI           , -- In  :
            GPO             => I_GPO           , -- Out :
            REPORT_STATUS   => I_REPORT        , -- Out :
            FINISH          => I_FINISH          -- Out :
        );                                       -- 
    -------------------------------------------------------------------------------
    --
    -------------------------------------------------------------------------------
    O: AXI4_STREAM_SLAVE_PLAYER                  -- 
        generic map (                            -- 
            SCENARIO_FILE   => SCENARIO_FILE   , --
            NAME            => "O"             , --
            OUTPUT_DELAY    => DELAY           , --
            SYNC_PLUG_NUM   => 3               , --
            WIDTH           => O_WIDTH         , --
            SYNC_WIDTH      => SYNC_WIDTH      , --
            GPI_WIDTH       => GPI_WIDTH       , --
            GPO_WIDTH       => GPO_WIDTH       , --
            FINISH_ABORT    => FALSE             --
        )                                        -- 
        port map(                                -- 
            ACLK            => CLOCK           , -- In  :
            ARESETn         => ARESETn         , -- In  :
            TDATA           => O_TDATA         , -- In  :
            TSTRB           => O_TKEEP         , -- In  :
            TKEEP           => O_TKEEP         , -- In  :
            TUSER           => O_TUSER         , -- In  :
            TDEST           => O_TDEST         , -- In  :
            TID             => O_TID           , -- In  :
            TLAST           => O_TLAST         , -- In  :
            TVALID          => O_TVALID        , -- In  :
            TREADY          => O_TREADY        , -- Out :
            SYNC            => SYNC            , -- Inou:
            GPI             => O_GPI           , -- In  :
            GPO             => O_GPO           , -- Out :
            REPORT_STATUS   => O_REPORT        , -- Out :
            FINISH          => O_FINISH          -- Out :
        );                                       -- 
    ------------------------------------------------------------------------------
    -- AXI4_SLAVE_PLAYER
    ------------------------------------------------------------------------------
    M: AXI4_SLAVE_PLAYER
        generic map (
            SCENARIO_FILE   => SCENARIO_FILE   ,
            NAME            => "M"             ,
            READ_ENABLE     => TRUE            ,
            WRITE_ENABLE    => FALSE           ,
            OUTPUT_DELAY    => DELAY           ,
            WIDTH           => M_WIDTH         ,
            SYNC_PLUG_NUM   => 4               ,
            SYNC_WIDTH      => SYNC_WIDTH      ,
            GPI_WIDTH       => GPI_WIDTH       ,
            GPO_WIDTH       => GPO_WIDTH       ,
            FINISH_ABORT    => FALSE
        )
        port map(
        ---------------------------------------------------------------------------
        -- 
        ---------------------------------------------------------------------------
            ACLK            => CLOCK           , -- In  :
            ARESETn         => ARESETn         , -- In  :
        ---------------------------------------------------------------------------
        -- 
        ---------------------------------------------------------------------------
            ARADDR          => M_ARADDR        , -- In  :    
            ARLEN           => M_ARLEN         , -- In  :    
            ARSIZE          => M_ARSIZE        , -- In  :    
            ARBURST         => M_ARBURST       , -- In  :    
            ARLOCK          => M_ARLOCK        , -- In  :    
            ARCACHE         => M_ARCACHE       , -- In  :    
            ARPROT          => M_ARPROT        , -- In  :    
            ARQOS           => M_ARQOS         , -- In  :    
            ARREGION        => M_ARREGION      , -- In  :    
            ARUSER          => M_ARUSER        , -- In  :    
            ARID            => M_ARID          , -- In  :    
            ARVALID         => M_ARVALID       , -- In  :    
            ARREADY         => M_ARREADY       , -- I/O : 
        ---------------------------------------------------------------------------
        -- 
        ---------------------------------------------------------------------------
            RLAST           => M_RLAST         , -- I/O : 
            RDATA           => M_RDATA         , -- I/O : 
            RRESP           => M_RRESP         , -- I/O : 
            RUSER           => M_RUSER         , -- I/O : 
            RID             => M_RID           , -- I/O : 
            RVALID          => M_RVALID        , -- I/O : 
            RREADY          => M_RREADY        , -- In  :    
        ---------------------------------------------------------------------------
        -- 
        ---------------------------------------------------------------------------
            AWADDR          => M_AWADDR        , -- In  :    
            AWLEN           => M_AWLEN         , -- In  :    
            AWSIZE          => M_AWSIZE        , -- In  :    
            AWBURST         => M_AWBURST       , -- In  :    
            AWLOCK          => M_AWLOCK        , -- In  :    
            AWCACHE         => M_AWCACHE       , -- In  :    
            AWPROT          => M_AWPROT        , -- In  :    
            AWQOS           => M_AWQOS         , -- In  :    
            AWREGION        => M_AWREGION      , -- In  :    
            AWUSER          => M_AWUSER        , -- In  :    
            AWID            => M_AWID          , -- In  :    
            AWVALID         => M_AWVALID       , -- In  :    
            AWREADY         => M_AWREADY       , -- I/O : 
        ---------------------------------------------------------------------------
        -- 
        ---------------------------------------------------------------------------
            WLAST           => M_WLAST         , -- In  :    
            WDATA           => M_WDATA         , -- In  :    
            WSTRB           => M_WSTRB         , -- In  :    
            WUSER           => M_WUSER         , -- In  :    
            WID             => M_WID           , -- In  :    
            WVALID          => M_WVALID        , -- In  :    
            WREADY          => M_WREADY        , -- I/O : 
        --------------------------------------------------------------------------
        -- 
        --------------------------------------------------------------------------
            BRESP           => M_BRESP         , -- I/O : 
            BUSER           => M_BUSER         , -- I/O : 
            BID             => M_BID           , -- I/O : 
            BVALID          => M_BVALID        , -- I/O : 
            BREADY          => M_BREADY        , -- In  :    
        ---------------------------------------------------------------------------
        -- 
        ---------------------------------------------------------------------------
            SYNC            => SYNC            , -- I/O :
        --------------------------------------------------------------------------
        -- 
        --------------------------------------------------------------------------
            GPI             => M_GPI           , -- In  :
            GPO             => M_GPO           , -- Out :
        --------------------------------------------------------------------------
        -- 
        --------------------------------------------------------------------------
            REPORT_STATUS   => M_REPORT        , -- Out :
            FINISH          => M_FINISH          -- Out :
    );
    -------------------------------------------------------------------------------
    -- 
    -------------------------------------------------------------------------------
    DUT: SHA256_Server                           -- 
        generic map (                            -- 
            I_BYTES         => I_BYTES         , --
            O_BYTES         => O_BYTES           --
        )                                        -- 
        port map (                               -- 
            CLK             => CLOCK           , -- In  :
            ARESETn         => ARESETn         , -- In  :
            I_TDATA         => I_TDATA         , -- In  :
            I_TKEEP         => I_TKEEP         , -- In  :
            I_TLAST         => I_TLAST         , -- In  :
            I_TVALID        => I_TVALID        , -- In  :
            I_TREADY        => I_TREADY        , -- Out :
            O_TDATA         => O_TDATA         , -- Out :
            O_TKEEP         => O_TKEEP         , -- Out :
            O_TLAST         => O_TLAST         , -- Out :
            O_TVALID        => O_TVALID        , -- Out :
            O_TREADY        => O_TREADY        , -- In  :
            BUF_ARADDR      => M_ARADDR        , -- Out :
            BUF_ARVALID     => M_ARVALID       , -- Out :
            BUF_ARREADY     => M_ARREADY       , -- In  :
            BUF_ARLEN       => M_ARLEN         , -- Out :
            BUF_ARBURST     => M_ARBURST       , -- Out :
            BUF_ARSIZE      => M_ARSIZE        , -- Out :
            BUF_ARCACHE     => M_ARCACHE       , -- Out :
            BUF_RVALID      => M_RVALID        , -- In  :
            BUF_RDATA       => M_RDATA         , -- In  :
            BUF_RREADY      => M_RREADY        , -- Out :
            BUF_RLAST       => M_RLAST         , -- In  :
            BUF_AWADDR      => M_AWADDR        , -- Out :
            BUF_AWVALID     => M_AWVALID       , -- Out :
            BUF_AWREADY     => M_AWREADY       , -- In  :
            BUF_AWLEN       => M_AWLEN         , -- Out :
            BUF_AWBURST     => M_AWBURST       , -- Out :
            BUF_AWSIZE      => M_AWSIZE        , -- Out :
            BUF_AWCACHE     => M_AWCACHE       , -- Out :
            BUF_WVALID      => M_WVALID        , -- Out :
            BUF_WREADY      => M_WREADY        , -- In  :
            BUF_WDATA       => M_WDATA         , -- Out :
            BUF_WLAST       => M_WLAST         , -- Out :
            BUF_BVALID      => M_BVALID        , -- In  :
            BUF_BREADY      => M_BREADY        , -- Out :
            BUF_BRESP       => M_BRESP           -- In  :
        );
    -------------------------------------------------------------------------------
    -- 
    -------------------------------------------------------------------------------
    process begin
        CLOCK <= '0';
        wait for CLOCK_PERIOD / 2;
        CLOCK <= '1';
        wait for CLOCK_PERIOD / 2;
    end process;

    ARESETn <= '1' when (RESET = '0') else '0';
    process
        variable L   : LINE;
        constant T   : STRING(1 to 7) := "  ***  ";
    begin
        wait until (O_FINISH'event and O_FINISH = '1');
        wait for DELAY;
        WRITE(L,T);                                                   WRITELINE(OUTPUT,L);
        WRITE(L,T & "ERROR REPORT " & NAME);                          WRITELINE(OUTPUT,L);
        WRITE(L,T & "[ I ]");                                         WRITELINE(OUTPUT,L);
        WRITE(L,T & "  Error    : ");WRITE(L,I_REPORT.error_count   );WRITELINE(OUTPUT,L);
        WRITE(L,T & "  Mismatch : ");WRITE(L,I_REPORT.mismatch_count);WRITELINE(OUTPUT,L);
        WRITE(L,T & "  Warning  : ");WRITE(L,I_REPORT.warning_count );WRITELINE(OUTPUT,L);
        WRITE(L,T & "[ O ]");                                         WRITELINE(OUTPUT,L);
        WRITE(L,T & "  Error    : ");WRITE(L,O_REPORT.error_count   );WRITELINE(OUTPUT,L);
        WRITE(L,T & "  Mismatch : ");WRITE(L,O_REPORT.mismatch_count);WRITELINE(OUTPUT,L);
        WRITE(L,T & "  Warning  : ");WRITE(L,O_REPORT.warning_count );WRITELINE(OUTPUT,L);
        WRITE(L,T);                                                   WRITELINE(OUTPUT,L);
        WRITE(L,T & "[ M ]");                                         WRITELINE(OUTPUT,L);
        WRITE(L,T & "  Error    : ");WRITE(L,M_REPORT.error_count   );WRITELINE(OUTPUT,L);
        WRITE(L,T & "  Mismatch : ");WRITE(L,M_REPORT.mismatch_count);WRITELINE(OUTPUT,L);
        WRITE(L,T & "  Warning  : ");WRITE(L,M_REPORT.warning_count );WRITELINE(OUTPUT,L);
        WRITE(L,T);                                                   WRITELINE(OUTPUT,L);
        assert FALSE report "Simulation complete." severity FAILURE;
        wait;
    end process;
    
 -- SYNC_PRINT_0: SYNC_PRINT generic map(string'("AXI4_TEST_1:SYNC(0)")) port map (SYNC(0));
 -- SYNC_PRINT_1: SYNC_PRINT generic map(string'("AXI4_TEST_1:SYNC(1)")) port map (SYNC(1));
end MODEL;
-----------------------------------------------------------------------------------
--
-----------------------------------------------------------------------------------
