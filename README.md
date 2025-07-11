# Tokenized Inheritance Contracts 
A Clarity smart contract that enables automatic inheritance of digital assets based on account inactivity.

## 🎯 Features

- Set up inheritance for digital assets
- Specify heirs and inheritance amounts
- Automatic transfer triggers based on inactivity
- Update heir and inheritance details
- Claim inheritance after inactivity period

## 📝 Contract Functions

### For Asset Owners

- `initialize-inheritance`: Set up a new inheritance
- `set-inactivity-period`: Define the inactivity trigger period
- `update-activity`: Reset the inactivity timer
- `update-heir`: Change the designated heir
- `update-amount`: Modify the inheritance amount

### For Heirs

- `claim-inheritance`: Claim assets after inactivity period
- `get-inheritance`: View inheritance details
- `check-inactivity`: Check if inheritance is claimable

## 🚀 Usage

1. Deploy the contract
2. Initialize inheritance with:
   - Heir's principal
   - Inheritance amount
   - Asset type
3. Set inactivity period
4. Heirs can claim after inactivity period expires

## ⚠️ Important Notes

- Owner must regularly call `update-activity` to prevent premature inheritance
- Only designated heirs can claim inheritance
- Inheritance can only be claimed after the inactivity period
```

