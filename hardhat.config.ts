import { HardhatUserConfig } from 'hardhat/types';
import { eNetwork } from './helpers/types';
import { NETWORKS_RPC_URL } from './helper-hardhat-config';
import { NetworkUserConfig } from 'hardhat/types';
import dotenv from 'dotenv';
import glob from 'glob';
import path from 'path';
dotenv.config({ path: '../.env' });
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import '@typechain/hardhat';
import 'solidity-coverage';
import 'hardhat-gas-reporter';
import 'hardhat-contract-sizer';
import 'hardhat-log-remover';
import 'hardhat-spdx-license-identifier';

if (!process.env.SKIP_LOAD) {
  glob.sync('./tasks/**/*.ts').forEach(function (file) {
    require(path.resolve(file));
  });
}

const DEFAULT_BLOCK_GAS_LIMIT = 12450000;
const MNEMONIC_PATH = "m/44'/60'/0'/0";
const MNEMONIC = process.env.MNEMONIC || '';
const MAINNET_FORK = process.env.MAINNET_FORK === 'true';
const TRACK_GAS = process.env.TRACK_GAS === 'true';
const BLOCK_EXPLORER_KEY = process.env.BLOCK_EXPLORER_KEY || '';
const alchemyKey: string = process.env.ALCHEMY_KEY || '';

const getCommonNetworkConfig = (networkName: eNetwork, networkId: number) => ({
  url: NETWORKS_RPC_URL[networkName] ?? '',
  accounts: {
    mnemonic: MNEMONIC,
    path: MNEMONIC_PATH,
    initialIndex: 0,
    count: 20,
  },
});

const mainnetFork = MAINNET_FORK
  ? {
    blockNumber: 12012081,
    url: NETWORKS_RPC_URL['main'],
  }
  : undefined;

const chainIds = {
  local: 1337,
  opBNB: 5611,
  hardhat: 31337,
  ganache: 1337,
  qing: 1337,
  mainnet: 1,
  ropsten: 3,
  rinkeby: 4,
  goerli: 5,
  kovan: 42,
  avax: 43114,
  avax_testnet: 43113,
  fantom: 250,
  fantom_testnet: 4002,
  polygon: 137,
  mumbai: 80001,
  optimism: 10,
  optimism_testnet: 69,
  arbitrum: 42161,
  arbitrum_testnet: 421611,
  heco: 128,
  mantle: 5000,
  mantletest: 5001,
};

function createTestnetConfig(network: keyof typeof chainIds): NetworkUserConfig {
  if (!alchemyKey) {
    throw new Error('Missing ALCHEMY_KEY');
  }

  const polygonNetworkName = network === 'polygon' ? 'mainnet' : 'mumbai';

  let nodeUrl =
    chainIds[network] == 137 || chainIds[network] == 80001
      ? `https://polygon-${polygonNetworkName}.g.alchemy.com/v2/${alchemyKey}`
      : `https://eth-${network}.alchemyapi.io/v2/${alchemyKey}`;

  switch (network) {
    case 'optimism':
      nodeUrl = `https://opt-mainnet.g.alchemy.com/v2/${alchemyKey}`;
      break;
    case 'optimism_testnet':
      nodeUrl = `https://opt-kovan.g.alchemy.com/v2/${alchemyKey}`;
      break;
    case 'arbitrum':
      nodeUrl = `https://arb-mainnet.g.alchemy.com/v2/${alchemyKey}`;
      break;
    case 'arbitrum_testnet':
      nodeUrl = `https://arb-rinkeby.g.alchemy.com/v2/${alchemyKey}`;
      break;
    case 'avax':
      nodeUrl = 'https://api.avax.network/ext/bc/C/rpc';
      break;
    case 'avax_testnet':
      nodeUrl = 'https://api.avax-test.network/ext/bc/C/rpc';
      break;
    case 'fantom':
      nodeUrl = 'https://rpc.ftm.tools';
      break;
    case 'fantom_testnet':
      nodeUrl = 'https://rpc.testnet.fantom.network';
      break;
    case 'heco':
      nodeUrl = 'https://http-mainnet.hecochain.com';
      break;
    case 'ganache':
      nodeUrl = 'http://127.0.0.1:8545';
      break;
    case 'opBNB':
      nodeUrl = 'https://opbnb-testnet-rpc.bnbchain.org';
      break;
    case 'local':
      nodeUrl = 'http://127.0.0.1:8545';
      break;
    case 'mantle':
      nodeUrl = 'https://rpc.mantle.xyz';
      break;
    case 'mantletest':
      nodeUrl = 'https://rpc.testnet.mantle.xyz';
      break;
    case 'qing':
      nodeUrl = 'http://192.168.110.66:7545';
      break;
  }

  return {
    chainId: chainIds[network],
    url: nodeUrl,
    accounts: [
      '',
    ],
  };
}

const config: HardhatUserConfig = {
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY || process.env.SCAN_API_KEY,
      ropsten: process.env.ETHERSCAN_API_KEY || process.env.SCAN_API_KEY,
      rinkeby: process.env.ETHERSCAN_API_KEY || process.env.SCAN_API_KEY,
      goerli: process.env.ETHERSCAN_API_KEY || process.env.SCAN_API_KEY,
      kovan: process.env.ETHERSCAN_API_KEY || process.env.SCAN_API_KEY,
      polygon: process.env.POLYGONSCAN_API_KEY || process.env.SCAN_API_KEY,
      polygonMumbai: process.env.POLYGONSCAN_API_KEY || process.env.SCAN_API_KEY,
      opera: process.env.FANTOMSCAN_API_KEY || process.env.SCAN_API_KEY,
      ftmTestnet: process.env.FANTOMSCAN_API_KEY || process.env.SCAN_API_KEY,
      avalanche: process.env.SNOWTRACE_API_KEY || process.env.SCAN_API_KEY,
      avalancheFujiTestnet: process.env.SNOWTRACE_API_KEY || process.env.SCAN_API_KEY,
      optimisticEthereum: process.env.OPTIMISM_SCAN_API_KEY || process.env.SCAN_API_KEY,
      optimisticKovan: process.env.OPTIMISM_SCAN_API_KEY || process.env.SCAN_API_KEY,
      arbitrumOne: process.env.ARBITRUM_SCAN_API_KEY || process.env.SCAN_API_KEY,
      arbitrumTestnet: process.env.ARBITRUM_SCAN_API_KEY || process.env.SCAN_API_KEY,
      heco: process.env.ARBITRUM_SCAN_API_KEY || process.env.SCAN_API_KEY,
      mantle: '',
      qing: '',
    },
  },
  solidity: {
    compilers: [
      {
        version: '0.8.10',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
            details: {
              yul: true,
            },
          },
        },
      },
    ],
  },
  networks: {
    local: createTestnetConfig('local'),
    opBNB: createTestnetConfig('opBNB'),
    ganache: createTestnetConfig('ganache'),
    mainnet: createTestnetConfig('mainnet'),
    goerli: createTestnetConfig('goerli'),
    rinkeby: createTestnetConfig('rinkeby'),
    polygon: createTestnetConfig('polygon'),
    mumbai: createTestnetConfig('mumbai'),
    fantom: createTestnetConfig('fantom'),
    fantom_testnet: createTestnetConfig('fantom_testnet'),
    avax: createTestnetConfig('avax'),
    avax_testnet: createTestnetConfig('avax_testnet'),
    arbitrum: createTestnetConfig('arbitrum'),
    arbitrum_testnet: createTestnetConfig('arbitrum_testnet'),
    optimism: createTestnetConfig('optimism'),
    optimism_testnet: createTestnetConfig('optimism_testnet'),
    heco: createTestnetConfig('heco'),
    mantle: createTestnetConfig('mantle'),
    mantletest: createTestnetConfig('mantletest'),
    qing: createTestnetConfig('qing'),
  },
  gasReporter: {
    enabled: TRACK_GAS,
  },
  spdxLicenseIdentifier: {
    overwrite: false,
    runOnCompile: false,
  },
  etherscan: {
    apiKey: BLOCK_EXPLORER_KEY,
  },
};

export default config;
