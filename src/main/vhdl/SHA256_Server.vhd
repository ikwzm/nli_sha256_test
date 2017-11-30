library ieee;
use     ieee.std_logic_1164.all;
entity  SHA256_Server is
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
        BUF_ARSIZE           : out std_logic_vector( 2 downto 0);
        BUF_ARBURST          : out std_logic_vector( 1 downto 0);
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
        BUF_AWBURST          : out std_logic_vector( 1 downto 0);
        BUF_AWCACHE          : out std_logic_vector( 3 downto 0);
        BUF_WVALID           : out std_logic;
        BUF_WREADY           : in  std_logic;
        BUF_WDATA            : out std_logic_vector(31 downto 0);
        BUF_WLAST            : out std_logic;
        BUF_BVALID           : in  std_logic;
        BUF_BREADY           : out std_logic;
        BUF_BRESP            : in  std_logic_vector( 1 downto 0)
    );
end     SHA256_Server;
library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
architecture RTL of SHA256_Server is
    signal    reset            :  std_logic;
    signal    reset_n          :  std_logic;
    signal    sha256_req_valid :  std_logic;
    signal    sha256_req_ready :  std_logic;
    signal    sha256_res_valid :  std_logic;
    signal    sha256_res_ready :  std_logic;
    signal    sha256_req_0     :  std_logic_vector(32-1 downto 0);
    signal    sha256_req_1     :  std_logic_vector(32-1 downto 0);
    signal    sha256_res_0     :  std_logic_vector(256-1 downto 0);
    component SHA256_Interface is
        generic(
            I_BYTES              : integer := 1;
            O_BYTES              : integer := 1
        );
        port(
            CLK                  : in  std_logic;
            RST                  : in  std_logic;
            CLR                  : in  std_logic;
            I_DATA               : in  std_logic_vector(8*I_BYTES-1 downto 0);
            I_STRB               : in  std_logic_vector(  I_BYTES-1 downto 0);
            I_LAST               : in  std_logic;
            I_VALID              : in  std_logic;
            I_READY              : out std_logic;
            O_DATA               : out std_logic_vector(8*O_BYTES-1 downto 0);
            O_STRB               : out std_logic_vector(  O_BYTES-1 downto 0);
            O_LAST               : out std_logic;
            O_VALID              : out std_logic;
            O_READY              : in  std_logic;
            sha256_req_valid     : out std_logic;
            sha256_req_ready     : in  std_logic;
            sha256_res_valid     : in  std_logic;
            sha256_res_ready     : out std_logic;
            sha256_req_0         : out std_logic_vector(32-1 downto 0);
            sha256_req_1         : out std_logic_vector(32-1 downto 0);
            sha256_res_0         : in  std_logic_vector(256-1 downto 0)
        );
    end component;
    component sha256 is
        port(
            clk                  : in  std_logic;
            rst                  : in  std_logic;
            buf_ARADDR           : out std_logic_vector(31 downto 0);
            buf_ARVALID          : out std_logic;
            buf_ARREADY          : in  std_logic;
            buf_ARLEN            : out std_logic_vector( 7 downto 0);
            buf_ARSIZE           : out std_logic_vector( 2 downto 0);
            buf_RVALID           : in  std_logic;
            buf_RDATA            : in  std_logic_vector(31 downto 0);
            buf_RREADY           : out std_logic;
            buf_RLAST            : in  std_logic;
            buf_AWADDR           : out std_logic_vector(31 downto 0);
            buf_AWVALID          : out std_logic;
            buf_AWREADY          : in  std_logic;
            buf_AWLEN            : out std_logic_vector( 7 downto 0);
            buf_AWSIZE           : out std_logic_vector( 2 downto 0);
            buf_WVALID           : out std_logic;
            buf_WREADY           : in  std_logic;
            buf_WDATA            : out std_logic_vector(31 downto 0);
            buf_WLAST            : out std_logic;
            buf_BVALID           : in  std_logic;
            buf_BREADY           : out std_logic;
            buf_BRESP            : in  std_logic_vector( 1 downto 0);
            sha256_req_valid     : in  std_logic;
            sha256_req_ready     : out std_logic;
            sha256_res_valid     : out std_logic;
            sha256_res_ready     : in  std_logic;
            sha256_req_0         : in  std_logic_vector(32-1 downto 0);
            sha256_req_1         : in  std_logic_vector(32-1 downto 0);
            sha256_res_0         : out std_logic_vector(256-1 downto 0)
        );
    end component;
begin
    reset      <= not ARESETn;
    reset_n    <=     ARESETn;
    U : SHA256_Interface
        generic map(
            I_BYTES              => I_BYTES             ,
            O_BYTES              => O_BYTES             
        )
        port map(
            CLK                  => CLK                 ,
            RST                  => reset               ,
            CLR                  => '0'                 ,
            I_DATA               => I_TDATA             ,
            I_STRB               => I_TKEEP             ,
            I_LAST               => I_TLAST             ,
            I_VALID              => I_TVALID            ,
            I_READY              => I_TREADY            ,
            O_DATA               => O_TDATA             ,
            O_STRB               => O_TKEEP             ,
            O_LAST               => O_TLAST             ,
            O_VALID              => O_TVALID            ,
            O_READY              => O_TREADY            ,
            sha256_req_valid     => sha256_req_valid    ,
            sha256_req_ready     => sha256_req_ready    ,
            sha256_res_valid     => sha256_res_valid    ,
            sha256_res_ready     => sha256_res_ready    ,
            sha256_req_0         => sha256_req_0        ,
            sha256_req_1         => sha256_req_1        ,
            sha256_res_0         => sha256_res_0        
        );
    T : sha256
        port map(
            clk                  => CLK                 ,
            rst                  => reset               ,
            buf_ARADDR           => BUF_ARADDR          , -- Out :
            buf_ARVALID          => BUF_ARVALID         , -- Out :
            buf_ARREADY          => BUF_ARREADY         , --   In  :
            buf_ARLEN            => BUF_ARLEN           , --   Out :
            buf_ARSIZE           => BUF_ARSIZE          , --   Out :
            buf_RVALID           => BUF_RVALID          , --   In  :
            buf_RDATA            => BUF_RDATA           , --   In  :
            buf_RREADY           => BUF_RREADY          , --   Out :
            buf_RLAST            => BUF_RLAST           , --   In  :
            buf_AWADDR           => BUF_AWADDR          , --   Out :
            buf_AWVALID          => BUF_AWVALID         , --   Out :
            buf_AWREADY          => BUF_AWREADY         , --   In  :
            buf_AWLEN            => BUF_AWLEN           , --   Out :
            buf_AWSIZE           => BUF_AWSIZE          , --   Out :
            buf_WVALID           => BUF_WVALID          , --   Out :
            buf_WREADY           => BUF_WREADY          , --   In  :
            buf_WDATA            => BUF_WDATA           , --   Out :
            buf_WLAST            => BUF_WLAST           , --   Out :
            buf_BVALID           => BUF_BVALID          , --   In  :
            buf_BREADY           => BUF_BREADY          , --   Out :
            buf_BRESP            => BUF_BRESP           , --   In  :
            sha256_req_valid     => sha256_req_valid    ,
            sha256_req_ready     => sha256_req_ready    ,
            sha256_res_valid     => sha256_res_valid    ,
            sha256_res_ready     => sha256_res_ready    ,
            sha256_req_0         => sha256_req_0        ,
            sha256_req_1         => sha256_req_1        ,
            sha256_res_0         => sha256_res_0        
        );
    BUF_ARCACHE <= "0011";
    BUF_AWCACHE <= "0011";
    BUF_ARBURST <= "01";
    BUF_AWBURST <= "01";
end RTL;
