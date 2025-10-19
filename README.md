Decentralized cotton traceability platform empowering farmers through blockchain technology

## 🎯 Overview

CottonChain is a revolutionary blockchain-based platform that connects cotton farmers directly with textile mills, eliminating middleman exploitation and ensuring fair trade practices. Built on the Stacks blockchain using Clarity smart contracts.

## ✨ Key Features

### 🏷️ **Cotton Bale NFTs**
- Each cotton bale is tokenized as a unique NFT
- Immutable farm and laboratory data attached
- Quality grades and certifications tracked
- Complete harvest and processing history

### 🌾 **Batch Minting**
- Mint multiple cotton bale NFTs in a single transaction
- Optimized for large-scale farming operations
- Reduces transaction costs and improves efficiency

### 💰 **Smart Escrow System**
- Secure transactions between farmers and mills
- Automated payment release upon completion
- Built-in dispute resolution mechanisms
- Platform fee collection (2.5% default)

### ⚖️ **Dispute Resolution Mechanism**
- Initiate disputes on pending escrows for fair resolution
- Contract owner arbitrates and distributes funds accordingly
- Transparent and trust-enhancing process
- Prevents fraudulent transactions and ensures accountability

### 📋 **Public Audit Trail**
- Complete transaction history
- Real-time status tracking
- Transparent supply chain monitoring
- Immutable record keeping

### ⭐ **Reputation System**
- Rate buyers and sellers (1-5 stars)
- Build trust through transparent feedback
- Community-driven quality assurance
- Fair trade verification

## 🛠️ Usage Instructions

### 🌾 **For Farmers**

#### Mint a Cotton Bale NFT
```clarity
(contract-call? .cotton-chain mint-cotton-bale
  "Farm Location, State"
  u500                    ;; weight in kg
  "Grade A"              ;; quality grade
  u1000                  ;; harvest date (block height)
  true                   ;; lab certified
  "abc123..."            ;; lab report hash
  u50)                   ;; price per kg in microSTX
```

#### Batch Mint Cotton Bale NFTs
```clarity
(contract-call? .cotton-chain batch-mint-cotton-bales
  (list
    {farm-location: "Farm A", weight-kg: u500, quality-grade: "Grade A", harvest-date: u1000, lab-certified: true, lab-report-hash: "hash1", price-per-kg: u50}
    {farm-location: "Farm B", weight-kg: u600, quality-grade: "Grade B", harvest-date: u1001, lab-certified: false, lab-report-hash: "hash2", price-per-kg: u45}
  )
)
```

#### Update Bale Status
```clarity
(contract-call? .cotton-chain update-bale-status u1 "shipped")
```

### 🏭 **For Mills/Buyers**

#### Create Escrow Agreement
```clarity
(contract-call? .cotton-chain create-escrow 
  u1                     ;; bale ID
  u144)                  ;; deadline (blocks, ~24 hours)
```

#### Complete Purchase
```clarity
(contract-call? .cotton-chain complete-escrow u1)
```

#### Cancel Escrow (if needed)
```clarity
(contract-call? .cotton-chain cancel-escrow u1)
```

#### Initiate Dispute
```clarity
(contract-call? .cotton-chain initiate-dispute u1 "Product quality not as described")
```

#### Resolve Dispute (Admin Only)
```clarity
(contract-call? .cotton-chain resolve-dispute u1 u500 u0)  ;; Buyer gets full refund, seller gets nothing
```

### 👥 **For All Users**

#### Rate a User
```clarity
(contract-call? .cotton-chain rate-user 'SP1234... u5)  ;; 5-star rating
```

#### Check Bale Information
```clarity
(contract-call? .cotton-chain get-bale-data u1)
```

#### View User Reputation
```clarity
(contract-call? .cotton-chain get-user-rating 'SP1234...)
```

## 📊 Contract Functions

### 📖 **Read-Only Functions**
- `get-bale-data` - Retrieve cotton bale information
- `get-escrow` - Check escrow agreement details  
- `get-user-rating` - View user reputation scores
- `get-audit-entry` - Access audit trail records
- `get-next-bale-id` - Get next available bale ID
- `get-platform-fee` - Check current platform fee

### ✍️ **Public Functions**
- `mint-cotton-bale` - Create new cotton bale NFT
- `batch-mint-cotton-bales` - Create multiple cotton bale NFTs at once
- `create-escrow` - Start escrow agreement
- `complete-escrow` - Finalize transaction
- `cancel-escrow` - Cancel pending transaction
- `initiate-dispute` - Raise dispute on pending escrow
- `resolve-dispute` - Admin resolution of disputes
- `rate-user` - Submit user rating
- `update-bale-status` - Update bale status
- `set-platform-fee` - Admin fee adjustment

## 🏗️ Contract Structure

### 📝 **Data Structures**

**Cotton Bale Data:**
- Farmer address
- Farm location
- Weight (kg)
- Quality grade
- Harvest date
- Lab certification status
- Lab report hash
- Price per kg
- Current status

**Escrow Agreements:**
- Bale ID
- Buyer/seller addresses
- Total amount
- Status
- Creation time
- Deadline

**User Ratings:**
- Total score
- Rating count
- Average reputation

**Audit Trail:**
- Bale ID
- Action performed
- Actor address
- Timestamp
- Additional details

**Disputes:**
- Escrow ID
- Initiator address
- Reason for dispute
- Status (open/resolved)
- Creation timestamp
- Resolution timestamp (optional)

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet configured
- Basic understanding of Clarity language

### Local Development
```bash
# Clone the repository
git clone https://github.com/your-username/cottonchain.git

# Navigate to project
cd cottonchain

# Start Clarinet console
clarinet console

# Deploy contract
(contract-call? .cotton-chain mint-cotton-bale ...)
```

### Testing
```bash
# Run test suite
clarinet test

# Check contract syntax
clarinet check
```

## 🔒 Security Features

- ✅ Authorization checks on all critical functions
- ✅ Input validation and error handling
- ✅ Reentrancy protection
- ✅ Overflow/underflow protection
- ✅ Access control for admin functions

## 🌍 Impact

### 👨‍🌾 **For Farmers**
- 📈 Direct market access
- 💵 Fair pricing
- 🛡️ Protection from exploitation
- 📊 Transparent transactions

### 🏭 **For Mills**
- ✅ Quality assurance
- 📋 Supply chain transparency
- 🤝 Direct farmer relationships
- ⚡ Efficient procurement

### 🌱 **For Environment**
- 📍 Traceability promotes sustainable farming
- 🔄 Reduced supply chain complexity
- 📈 Incentivizes quality over quantity

## 🤝 Contributing

We welcome contributions! Please see our contributing guidelines and submit pull requests for any improvements.

## 📄 License

MIT License - see LICENSE file for details.

## 🆘 Support

For questions or support, please open an issue on GitHub or contact our team.

---

*Built with ❤️ for sustainable cotton farming*
