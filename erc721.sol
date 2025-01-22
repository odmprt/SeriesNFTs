//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract SeriesNFTs is ERC721, ReentrancyGuard {
    using Counters for Counters.Counter;
    address private owner;  //Variable para almacenar la dirección del propietario
    IERC20 public tokenAddress;  //Dirección del token ERC20
    uint256 public rate = 1 * 10 ** 18; //Valor de minteo - 1 EPI
    uint256 public maxWithdrawalAmount = 100 * 10 ** 18;
    string public baseTokenURI;  //URL base para los metadatos
    Counters.Counter private _tokenIdCounter;
    event Mint(address indexed user, uint256 tokenId);
    event Whitelisted(address indexed user);
    event RemovedFromWhitelist(address indexed user);
    event NFTBought(address indexed buyer, uint256 indexed tokenId, uint256 price);

    mapping(address => bool) public whitelisted;  //Lista blanca de direcciones

    constructor(address _tokenAddress, string memory _baseTokenURI) 
        ERC721("SeriesNFTs", "SNFT") {  
            owner = msg.sender;  //Establecemos el propietario al desplegar el contrato
            tokenAddress = IERC20(_tokenAddress);
            baseTokenURI = _baseTokenURI;

            //Añadimos automáticamente al propietario a la lista blanca
            whitelisted[owner] = true;
    }

    //Función que devuelve la URL asociada a un token específico que contiene sus metadatos
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            ownerOf(tokenId) != address(0),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return baseTokenURI; // Devuelve la URL base proporcionada
    }


    //Modificador personalizado para verificar si el mensaje proviene de una dirección en la lista blanca
    modifier onlyWhitelisted() {
        require(whitelisted[msg.sender], "You are not whitelisted to perform this action");
        _;
    }

    //Modificador personalizado para verificar si el mensaje proviene del propietario
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    //Función para agregar direcciones a la lista blanca, solo el propietario puede ejecutarla
    function addToWhitelist(address user) external onlyOwner {
        require(user != owner, "Owner cannot be added to the whitelist");
        require(!whitelisted[user], "Address is already whitelisted");
        whitelisted[user] = true;
        emit Whitelisted(user);
    }

    //Función para eliminar direcciones de la lista blanca, solo el propietario puede ejecutarla
    function removeFromWhitelist(address user) external onlyOwner {
        require(user != owner, "Owner cannot be removed from the whitelist");
        require(whitelisted[user], "Address is not whitelisted");
        whitelisted[user] = false;
        emit RemovedFromWhitelist(user);
    }

    //Función para acuñar un NFT solo si la dirección está en la lista blanca
    function safeMint() public onlyWhitelisted {
        //Verificamos si el usuario tiene suficientes tokens
        require(tokenAddress.balanceOf(msg.sender) >= rate, "Not enough tokens to mint");

        //Intentamos hacer la transferencia
        require(tokenAddress.transferFrom(msg.sender, address(this), rate), "Payment failed");

        //Crear el nuevo token
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
        emit Mint(msg.sender, tokenId);
    }

    //Función para retirar los tokens ERC20 del contrato solo si la dirección está en la lista blanca
    function withdraw(uint256 amount) external onlyWhitelisted nonReentrant {
        uint256 allowance = tokenAddress.allowance(msg.sender, address(this));  //Verifica los tokens aprobados para el contrato ERC721
        //Limitar la cantidad de tokens que se pueden retirar
        require(amount <= maxWithdrawalAmount, "Withdrawal exceeds the limit");
        
        require(allowance >= amount, "Not enough approved tokens to withdraw");
        
        //Transfiere los tokens ERC20 desde el usuario al contrato ERC721
        require(tokenAddress.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        //Los tokens ahora están almacenados dentro del contrato y pueden ser utilizados más tarde como para la conversión a otra moneda
    }

    //Función que permite a un usuario comprar un NFT mediante el pago en tokens ERC20, transfiriendo el token al propietario actual y el NFT al comprador
    function buyNFT(uint256 tokenId) public nonReentrant {
        //Obtenemos el precio del NFT y verificamos usuario tenga suficientes tokens
        uint256 price = getMintPrice();
        require(tokenAddress.balanceOf(msg.sender) >= price, "Not enough EPIS to buy NFT");
        
        //Verificamos que el comprador no sea el propietario
        address seller = ownerOf(tokenId);
        require(msg.sender != seller, "You cannot buy your own NFT");

        //Calculamos la comisión (1% del precio) y se la transferimos al propietario del contrato
        uint256 commission = price / 100; // 1% de comisión
        require(tokenAddress.transferFrom(msg.sender, owner, commission), "Commission transfer failed");

        //Transferimos el precio al propietario del NFT
        require(tokenAddress.transferFrom(msg.sender, seller, price - commission), "Transfer failed");

        //Transferimos el NFT al comprador
        _safeTransfer(seller, msg.sender, tokenId, "");

        //Emitimos un evento para la compra
        emit NFTBought(msg.sender, tokenId, price);
    }


    //Función para ver el balance de tokens del contrato
    function getBalance() external view returns (uint256) {
        return tokenAddress.balanceOf(address(this));
    }

    //Función para cambiar el precio del NFT solo si la dirección está en la lista blanca
    function setRate(uint256 newRate) public onlyWhitelisted {
        rate = newRate;
    }

    //Función para ver el precio de acuñar un NFT
    function getMintPrice() public view returns (uint256) {
        return rate;
    }

    //Función para cambiar la cantidad máxima de tokens a retirar
    function setMaxWithdrawalAmount(uint256 newLimit) external onlyWhitelisted {
        maxWithdrawalAmount = newLimit;
    }

    //Función para ver el propietario de un NFT 
    function getOwnerOf(uint256 tokenId) public view onlyWhitelisted returns (address) {
        return ownerOf(tokenId); // Devolvemos la dirección del propietario
    }
      
}