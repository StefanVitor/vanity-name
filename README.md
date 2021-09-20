
<!-- PROJECT LOGO -->
<br />
<p align="center">

  <h3 align="center">Vanity Name System</h3>

  <p align="center">
    Vanity name registering system resistant against frontrunning
    <br />
  </p>
</p>



<!-- TABLE OF CONTENTS -->
<details open="open">
  <summary>Table of Contents</summary>
  <ol>
    <li><a href="#about-the-project">About The Project</a></li>
    <li><a href="#built-with">Built With</a></li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
  </ol>
</details>



<!-- ABOUT THE PROJECT -->
## About The Project

Vanity name registering system resistant against frontrunning


## Built With

This project is built with:
* [Solidity](https://soliditylang.org/)
* [Truffle and Ganache](https://www.trufflesuite.com/)
* [Ethers.js](https://docs.ethers.io/v5/)

<!-- GETTING STARTED -->
## Getting Started

* This project consists of 3 smart contracts:
    
    - VanityNameRegistrar - base contract which inherits ERC721 contract. When I read project task, I recognized that every name should be unique and that should be ideal to be represented as NFT. So, in this project, every vanity name is one NFT.

    - VanityNamePrices - contract for calculate prices for vanity names.

    - VanityNameController - controller contract, which should be main connection between some future front-end and this vanity name system.



### Installation

1. Clone the repo
   ```sh
   git clone https://github.com/StefanVitor/vanity-name
   ```
2. npm install

3. If you want to deploy contracts to Rinkeby / Ropsten, it should be add secrets.json file in main directory with format
```
{
    "mnemonic": "abc def ghi..."
}
```

4. Deploy contracts on local truffle or Rinkeby / Ropsten network - truffle --network networkName migrate --reset 

5. Test contracts on local truffle or Rinkeby / Ropsten network - truffle --network networkName test


<!-- CONTRIBUTING -->
## Contributing

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request


<!-- LICENSE -->
## License

Distributed under the MIT. See `LICENSE` for more information.



<!-- CONTACT -->
## Contact

Stefan Vitorovic - [@StefanVitorovic](https://twitter.com/StefanVitorovic) - vitorovicstefan@gmail.com

Project Link: [https://github.com/StefanVitor/vanity-name](https://github.com/StefanVitor/vanity-name)


