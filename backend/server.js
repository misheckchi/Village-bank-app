require('dotenv').config();
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const mongoose = require('mongoose');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const UPLOADS_DIR = path.join(__dirname, 'uploads');
const INTEREST_RATE = 0.35; // 35%

// Ensure uploads directory exists
if (!fs.existsSync(UPLOADS_DIR)) {
    fs.mkdirSync(UPLOADS_DIR);
}

app.use(cors());
app.use(bodyParser.json({ limit: '10mb' }));
app.use('/uploads', express.static(UPLOADS_DIR));

// MongoDB Connection
const mongoUri = process.env.MONGODB_URI;
if (!mongoUri) {
    console.error('FATAL: MONGODB_URI is not defined in environment variables!');
} else {
    // Sanitize URI for logging (hide password)
    const sanitizedUri = mongoUri.replace(/:([^@]+)@/, ':****@');
    console.log(`[DB] Attempting connection to: ${sanitizedUri}`);
}

mongoose.connect(mongoUri, {
    serverSelectionTimeoutMS: 5000, // Timeout after 5s instead of 30s
})
    .then(() => {
        console.log('Successfully connected to MongoDB Atlas');
        console.log(`[DB] Database Name: ${mongoose.connection.name}`);
    })
    .catch(err => {
        console.error('CRITICAL: MongoDB connection error details:');
        console.error(`- Message: ${err.message}`);
        console.error(`- Code: ${err.code}`);
        if (err.reason) {
            console.error(`- Reason Type: ${err.reason.type}`);
            console.error(`- Servers Found: ${Object.keys(err.reason.servers || {}).length}`);
        }
    });

// Schemas
const UserSchema = new mongoose.Schema({
    phoneNumber: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    name: { type: String, required: true },
    role: { type: String, default: 'member' },
    savings: { type: Number, default: 0 },
    loan: { type: Number, default: 0 },
    interest: { type: Number, default: 0 }
});

const TransactionSchema = new mongoose.Schema({
    owner: String,
    title: String,
    date: String,
    amount: Number,
    type: String, // 'deposit' or 'withdrawal'
    timestamp: { type: Date, default: Date.now }
});

const PendingDepositSchema = new mongoose.Schema({
    owner: String,
    ownerName: String,
    amount: Number,
    transactionId: String,
    date: String,
    status: { type: String, default: 'pending' }
});

const PendingLoanSchema = new mongoose.Schema({
    amount: Number,
    interest: Number,
    requestedBy: String,
    requestedByPhone: String,
    receivingAccount: { type: String, default: '' },
    date: String,
    status: { type: String, default: 'pending' }
});

const PendingPayoutSchema = new mongoose.Schema({
    amount: Number,
    requestedBy: String,
    requestedByPhone: String,
    receivingAccount: { type: String, default: '' },
    date: String,
    status: { type: String, default: 'pending' }
});

const PendingRepaymentSchema = new mongoose.Schema({
    owner: String,
    ownerName: String,
    amount: Number,
    transactionId: String,
    date: String,
    status: { type: String, default: 'pending' }
});

const MessageSchema = new mongoose.Schema({
    sender: String,
    receiver: String,
    text: String,
    transactionId: String,
    imageUrl: String,
    timestamp: { type: Date, default: Date.now }
});

const LogSchema = new mongoose.Schema({
    title: String,
    desc: String,
    time: String,
    type: String,
    timestamp: { type: Date, default: Date.now }
});

const ReleaseSchema = new mongoose.Schema({
    version: String,
    buildNumber: String,
    downloadUrl: String,
    notes: String,
    timestamp: { type: Date, default: Date.now }
});

const ConfigSchema = new mongoose.Schema({
    key: String,
    value: Number
});

// Models
const User = mongoose.model('User', UserSchema);
const Transaction = mongoose.model('Transaction', TransactionSchema);
const PendingDeposit = mongoose.model('PendingDeposit', PendingDepositSchema);
const PendingLoan = mongoose.model('PendingLoan', PendingLoanSchema);
const PendingPayout = mongoose.model('PendingPayout', PendingPayoutSchema);
const PendingRepayment = mongoose.model('PendingRepayment', PendingRepaymentSchema);
const Message = mongoose.model('Message', MessageSchema);
const Log = mongoose.model('Log', LogSchema);
const Release = mongoose.model('Release', ReleaseSchema);
const Config = mongoose.model('Config', ConfigSchema);

// Helper for Bank Fund
async function getBankFund() {
    const config = await Config.findOne({ key: 'bankFund' });
    return config ? config.value : 0;
}

async function updateBankFund(amount) {
    await Config.findOneAndUpdate(
        { key: 'bankFund' },
        { $inc: { value: amount } },
        { upsert: true }
    );
}

// Auth Endpoints
app.post('/api/auth/login', async (req, res) => {
    const { phoneNumber, password } = req.body;
    if (phoneNumber.toLowerCase() === 'admin' && password === 'password') {
        return res.json({ success: true, role: 'admin', token: 'admin-token', name: 'Super Admin' });
    }
    try {
        const user = await User.findOne({ phoneNumber, password });
        if (user) {
            res.json({
                success: true,
                role: user.role,
                token: user.role === 'admin' ? 'admin-token' : user.phoneNumber,
                name: user.name
            });
        } else {
            res.status(401).json({ success: false, message: 'Invalid credentials' });
        }
    } catch (e) {
        res.status(500).json({ success: false });
    }
});

app.post('/api/auth/register', async (req, res) => {
    const { phoneNumber, password, fullName, role } = req.body;
    try {
        const existing = await User.findOne({ phoneNumber });
        if (existing) {
            return res.status(400).json({ success: false, message: 'User already exists' });
        }
        const newUser = new User({
            phoneNumber,
            password,
            name: fullName,
            role: role === 'admin' ? 'admin' : 'member'
        });
        await newUser.save();
        res.json({
            success: true,
            role: newUser.role,
            token: newUser.role === 'admin' ? 'admin-token' : newUser.phoneNumber,
            name: fullName
        });
    } catch (e) {
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

// Member Endpoints
app.get('/api/member/summary', async (req, res) => {
    const phone = req.query.phone;
    try {
        const user = await User.findOne({ phoneNumber: phone });
        if (!user) return res.status(404).json({ message: 'User not found' });

        const accruedInterest = user.interest !== undefined ? user.interest : (user.loan * INTEREST_RATE);
        res.json({
            savings: user.savings,
            loan: user.loan,
            accruedInterest: accruedInterest,
            totalToRepay: user.loan + accruedInterest,
            interestRate: INTEREST_RATE * 100
        });
    } catch (e) {
        res.status(500).json({ message: 'Error' });
    }
});

app.get('/api/member/transactions', async (req, res) => {
    const phone = req.query.phone;
    try {
        const txs = await Transaction.find({ owner: phone }).sort({ timestamp: -1 });
        res.json(txs);
    } catch (e) {
        res.status(500).json([]);
    }
});

app.post('/api/member/deposit', async (req, res) => {
    const { amount, phone, transactionId } = req.body;
    try {
        const user = await User.findOne({ phoneNumber: phone });
        if (!user) return res.status(404).json({ message: 'User not found' });

        const depositAmount = parseFloat(amount);
        const newPending = new PendingDeposit({
            owner: phone,
            ownerName: user.name,
            amount: depositAmount,
            transactionId: transactionId,
            date: new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
        });
        await newPending.save();

        const newLog = new Log({
            title: 'DEPOSIT SUBMITTED',
            desc: `MK ${depositAmount} submitted by ${user.name} (ID: ${transactionId})`,
            time: 'Now',
            type: 'warning'
        });
        await newLog.save();

        // AI Message
        setTimeout(async () => {
            const aiMessage = new Message({
                sender: 'admin-token',
                receiver: phone,
                text: `Hello ${user.name}, I have received your deposit request of MK ${depositAmount}. Please wait for the Admin's verification. It usually takes about 10 minutes for an Admin to click "Approve". Your transaction ID ${transactionId} is now in the queue.`
            });
            await aiMessage.save();
        }, 1000);

        res.json({ success: true, message: 'Deposit submitted for verification' });
    } catch (e) {
        res.status(500).json({ success: false });
    }
});

app.post('/api/member/loan', async (req, res) => {
    const { amount, phone, receivingAccount } = req.body;
    try {
        const user = await User.findOne({ phoneNumber: phone });
        if (!user) return res.status(404).json({ message: 'User not found' });

        const loanAmount = parseFloat(amount);

        // Check group fund (savings - loans)
        const allUsers = await User.find({});
        const totalSavings = allUsers.reduce((s, u) => s + u.savings, 0);
        const totalLoans = allUsers.reduce((s, u) => s + u.loan, 0);
        const groupFund = totalSavings - totalLoans;

        if (groupFund < loanAmount) {
            return res.status(400).json({ success: false, message: 'Insufficient group funds' });
        }

        const newLoan = new PendingLoan({
            amount: loanAmount,
            interest: loanAmount * INTEREST_RATE,
            requestedBy: user.name,
            requestedByPhone: phone,
            receivingAccount: receivingAccount || '',
            date: new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
        });
        await newLoan.save();

        await new Log({
            title: 'LOAN REQUEST',
            desc: `MK ${loanAmount} requested by ${user.name}`,
            time: 'Now',
            type: 'warning'
        }).save();

        setTimeout(async () => {
            await new Message({
                sender: 'admin-token',
                receiver: phone,
                text: `Loan request for MK ${loanAmount} received. The request has been forwarded to the Admin. Please wait for the Admin's verification and approval. It usually takes about 10 minutes for an Admin to click "Approve".`
            }).save();
        }, 1000);

        res.json({ success: true, loan: newLoan });
    } catch (e) {
        res.status(500).json({ success: false });
    }
});

app.post('/api/member/repay', async (req, res) => {
    const { amount, phone, transactionId } = req.body;
    try {
        const user = await User.findOne({ phoneNumber: phone });
        if (!user || user.loan <= 0) return res.status(400).json({ success: false, message: 'No active loans' });

        const repaymentAmount = parseFloat(amount);
        const newPending = new PendingRepayment({
            owner: phone,
            ownerName: user.name,
            amount: repaymentAmount,
            transactionId: transactionId,
            date: new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
        });
        await newPending.save();

        const newLog = new Log({
            title: 'REPAYMENT SUBMITTED',
            desc: `MK ${repaymentAmount} repayment submitted by ${user.name} (ID: ${transactionId})`,
            time: 'Now',
            type: 'warning'
        });
        await newLog.save();

        setTimeout(async () => {
            await new Message({
                sender: 'admin-token',
                receiver: phone,
                text: `Hello ${user.name}, I have received your loan repayment request of MK ${repaymentAmount}. Please wait for the Admin's verification. It usually takes about 10 minutes for an Admin to click "Approve". Your transaction ID ${transactionId} is now in the queue.`
            }).save();
        }, 1000);

        res.json({ success: true, message: 'Repayment submitted for verification' });
    } catch (e) {
        res.status(500).json({ success: false });
    }
});

app.post('/api/member/request-payout', async (req, res) => {
    const { amount, phone, receivingAccount } = req.body;
    try {
        const user = await User.findOne({ phoneNumber: phone });
        if (!user) return res.status(404).json({ message: 'User not found' });

        const payoutAmount = parseFloat(amount);
        if (user.savings < payoutAmount) {
            return res.status(400).json({ success: false, message: 'Insufficient savings' });
        }

        const newPayout = new PendingPayout({
            amount: payoutAmount,
            requestedBy: user.name,
            requestedByPhone: phone,
            receivingAccount: receivingAccount || '',
            date: new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
        });
        await newPayout.save();

        user.savings -= payoutAmount;
        await user.save();

        await new Log({
            title: 'PAYOUT REQUEST',
            desc: `MK ${payoutAmount} requested by ${user.name}`,
            time: 'Now',
            type: 'warning'
        }).save();

        setTimeout(async () => {
            await new Message({
                sender: 'admin-token',
                receiver: phone,
                text: `Your payout request for MK ${payoutAmount} is being processed. Please wait for the Admin's verification to receive funds on your SIM. It usually takes about 10 minutes for an Admin to click "Approve".`
            }).save();
        }, 1000);

        res.json({ success: true, payout: newPayout });
    } catch (e) {
        res.status(500).json({ success: false });
    }
});

// Admin Endpoints
app.get('/api/admin/overview', async (req, res) => {
    try {
        const users = await User.find({});
        const pLoans = await PendingLoan.countDocuments({ status: 'pending' });
        const pPayouts = await PendingPayout.countDocuments({ status: 'pending' });
        const pDeposits = await PendingDeposit.countDocuments({ status: 'pending' });
        const pRepayments = await PendingRepayment.countDocuments({ status: 'pending' });

        const totalSavings = users.reduce((s, u) => s + u.savings, 0);
        const totalLoans = users.reduce((s, u) => s + u.loan, 0);
        const bankFund = await getBankFund();

        const savingsValues = users.map(u => u.savings);
        const highestNet = savingsValues.length > 0 ? Math.max(...savingsValues) : 0;

        res.json({
            totalMembers: users.length,
            groupFund: totalSavings - totalLoans,
            totalLoans: totalLoans,
            pendingApprovals: pLoans + pRepayments,
            pendingPayouts: pPayouts,
            pendingDeposits: pDeposits,
            pendingRepayments: pRepayments,
            highestNet: highestNet,
            bankCommission: bankFund
        });
    } catch (e) {
        res.status(500).json({});
    }
});

app.get('/api/admin/pending-deposits', async (req, res) => {
    const data = await PendingDeposit.find({ status: 'pending' });
    res.json(data);
});

app.post('/api/admin/approve-deposit', async (req, res) => {
    const { depositId, approve } = req.body;
    try {
        const deposit = await PendingDeposit.findById(depositId);
        if (!deposit) return res.status(404).json({ success: false });

        if (approve) {
            const user = await User.findOne({ phoneNumber: deposit.owner });
            if (user) {
                user.savings += deposit.amount;
                await user.save();

                await new Transaction({
                    owner: user.phoneNumber,
                    title: 'Deposit Verified',
                    date: deposit.date,
                    amount: deposit.amount,
                    type: 'deposit'
                }).save();

                await new Log({
                    title: 'DEPOSIT VERIFIED',
                    desc: `MK ${deposit.amount} for ${user.name} approved.`,
                    time: 'Now',
                    type: 'success'
                }).save();
            }
        }
        await PendingDeposit.findByIdAndDelete(depositId);
        res.json({ success: true });
    } catch (e) {
        res.status(500).json({ success: false });
    }
});

app.get('/api/admin/pending-payouts', async (req, res) => {
    const data = await PendingPayout.find({ status: 'pending' });
    res.json(data);
});

app.post('/api/admin/process-payout', async (req, res) => {
    const { payoutId, confirm } = req.body;
    try {
        const payout = await PendingPayout.findById(payoutId);
        if (!payout) return res.status(404).json({ success: false });

        if (confirm) {
            await new Transaction({
                owner: payout.requestedByPhone,
                title: 'Payout Disbursed to SIM',
                date: new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
                amount: payout.amount,
                type: 'withdrawal'
            }).save();
            await PendingPayout.findByIdAndDelete(payoutId);
            return res.json({ success: true, phone: payout.receivingAccount || payout.requestedByPhone, amount: payout.amount });
        } else {
            const user = await User.findOne({ phoneNumber: payout.requestedByPhone });
            if (user) {
                user.savings += payout.amount;
                await user.save();
            }
        }
        await PendingPayout.findByIdAndDelete(payoutId);
        res.json({ success: true });
    } catch (e) {
        res.status(500).json({ success: false });
    }
});

app.get('/api/admin/pending-loans', async (req, res) => {
    const data = await PendingLoan.find({ status: 'pending' });
    res.json(data);
});

app.post('/api/admin/approve-loan', async (req, res) => {
    const { loanId, approve } = req.body;
    try {
        const loan = await PendingLoan.findById(loanId);
        if (!loan) return res.status(404).json({ success: false });

        if (approve) {
            const user = await User.findOne({ phoneNumber: loan.requestedByPhone });
            if (user) {
                user.loan += loan.amount;
                user.interest = (user.interest || 0) + (loan.amount * INTEREST_RATE);
                await user.save();

                await new Transaction({
                    owner: user.phoneNumber,
                    title: 'Loan Disbursed',
                    date: new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
                    amount: loan.amount,
                    type: 'deposit'
                }).save();

                // Return receiving account number/phone number and amount so frontend can trigger a National Bank USSD dialer
                await PendingLoan.findByIdAndDelete(loanId);
                return res.json({ success: true, phone: loan.receivingAccount || user.phoneNumber, amount: loan.amount });
            }
        }
        await PendingLoan.findByIdAndDelete(loanId);
        res.json({ success: true });
    } catch (e) {
        res.status(500).json({ success: false });
    }
});

app.get('/api/admin/pending-repayments', async (req, res) => {
    const data = await PendingRepayment.find({ status: 'pending' });
    res.json(data);
});

app.post('/api/admin/approve-repayment', async (req, res) => {
    const { repaymentId, approve } = req.body;
    try {
        const repayment = await PendingRepayment.findById(repaymentId);
        if (!repayment) return res.status(404).json({ success: false });

        if (approve) {
            const user = await User.findOne({ phoneNumber: repayment.owner });
            if (user && user.loan > 0) {
                const principal = user.loan;
                const memberProfit = principal * 0.30;
                const bankCut = principal * 0.05;

                await new Transaction({
                    owner: user.phoneNumber,
                    title: 'Loan Repayment Verified',
                    date: repayment.date,
                    amount: repayment.amount,
                    type: 'withdrawal'
                }).save();

                user.savings += memberProfit;
                user.loan = 0;
                user.interest = 0;
                await user.save();

                await updateBankFund(bankCut);

                await new Log({
                    title: 'REPAYMENT VERIFIED',
                    desc: `MK ${repayment.amount.toFixed(2)} repaid by ${user.name} approved.`,
                    time: 'Now',
                    type: 'success'
                }).save();
            }
        }
        await PendingRepayment.findByIdAndDelete(repaymentId);
        res.json({ success: true });
    } catch (e) {
        res.status(500).json({ success: false });
    }
});

app.get('/api/admin/logs', async (req, res) => {
    const logs = await Log.find({}).sort({ timestamp: -1 }).limit(50);
    res.json(logs);
});

app.get('/api/admin/users', async (req, res) => {
    const users = await User.find({});
    const data = users.map(u => ({
        name: u.name,
        phoneNumber: u.phoneNumber,
        role: u.role,
        savings: u.savings,
        loan: u.loan,
        interest: u.interest || (u.loan * INTEREST_RATE)
    }));
    res.json(data);
});

app.post('/api/admin/reset', async (req, res) => {
    await User.deleteMany({});
    await Transaction.deleteMany({});
    await PendingDeposit.deleteMany({});
    await PendingLoan.deleteMany({});
    await PendingPayout.deleteMany({});
    await PendingRepayment.deleteMany({});
    await Message.deleteMany({});
    await Log.deleteMany({});
    await Config.deleteMany({});

    await new Log({
        title: 'SYSTEM RESET',
        desc: 'All data has been cleared by Admin.',
        time: 'Now',
        type: 'danger'
    }).save();

    res.json({ success: true });
});

// Chat Endpoints
app.get('/api/chat', async (req, res) => {
    const { other, me } = req.query;
    try {
        let filtered;
        if (other === 'group') {
            filtered = await Message.find({ receiver: 'group' }).sort({ timestamp: 1 });
        } else {
            filtered = await Message.find({
                receiver: { $ne: 'group' },
                $or: [
                    { sender: me, receiver: other },
                    { sender: other, receiver: me }
                ]
            }).sort({ timestamp: 1 });
        }
        res.json(filtered);
    } catch (e) {
        res.status(500).json([]);
    }
});

app.post('/api/chat/send', async (req, res) => {
    const { sender, receiver, text, transactionId, imageUrl } = req.body;
    try {
        const newMessage = new Message({ sender, receiver, text, transactionId, imageUrl });
        await newMessage.save();
        res.json(newMessage);
    } catch (e) {
        res.status(500).json({ success: false });
    }
});

// Simple base64 upload handler
app.post('/api/upload', (req, res) => {
    const { image, fileName } = req.body;
    if (!image || !fileName) {
        return res.status(400).json({ success: false, message: 'Missing image data' });
    }

    const base64Data = image.replace(/^data:image\/\w+;base64,/, "");
    const filePath = path.join(UPLOADS_DIR, fileName);

    fs.writeFile(filePath, base64Data, 'base64', (err) => {
        if (err) {
            console.error('Upload error:', err);
            return res.status(500).json({ success: false });
        }

        // Use the request host to construct the URL dynamically
        const protocol = req.protocol;
        const host = req.get('host');
        const url = `${protocol}://${host}/uploads/${fileName}`;

        res.json({ success: true, url });
    });
});

// Release Tracking Endpoints
app.get('/api/releases', async (req, res) => {
    const releases = await Release.find({}).sort({ timestamp: -1 });
    res.json(releases);
});

app.post('/api/releases/log', async (req, res) => {
    const { version, buildNumber, downloadUrl, notes } = req.body;
    try {
        const newRelease = new Release({ version, buildNumber, downloadUrl, notes });
        await newRelease.save();

        await new Log({
            title: 'NEW RELEASE LOGGED',
            desc: `Version ${version}+${buildNumber} is now available.`,
            time: 'Now',
            type: 'info'
        }).save();

        res.json({ success: true, release: newRelease });
    } catch (e) {
        res.status(500).json({ success: false });
    }
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://localhost:${PORT}`);
});
