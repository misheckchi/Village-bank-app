require('dotenv').config();
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const mongoose = require('mongoose');

const app = express();
const PORT = process.env.PORT || 3000;
const INTEREST_RATE = 0.35; // 35%

app.use(cors());
app.use(bodyParser.json({ limit: '10mb' }));

// MongoDB Connection
const mongoUri = process.env.MONGODB_URI;
if (!mongoUri) {
    console.error('FATAL: MONGODB_URI is not defined in environment variables!');
} else {
    const sanitizedUri = mongoUri.replace(/:([^@]+)@/, ':****@');
    console.log(`[DB] Attempting connection to: ${sanitizedUri}`);
}

mongoose.connect(mongoUri, {
    serverSelectionTimeoutMS: 5000,
})
    .then(async () => {
        console.log('Successfully connected to MongoDB Atlas');
        console.log(`[DB] Database Name: ${mongoose.connection.name}`);
        await ensureDefaultOrganization();
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
const OrganizationSchema = new mongoose.Schema({
    name: { type: String, required: true },
    code: { type: String, required: true, unique: true },
    description: { type: String, default: '' },
    expectedMembers: { type: Number, default: 0 },
    contactPerson: { type: String, default: '' },
    contactPhone: { type: String, default: '' },
    contactEmail: { type: String, default: '' },
    adminName: { type: String, default: '' },
    adminPhone: { type: String, default: '' },
    status: { type: String, default: 'pending' }, // 'pending', 'approved', 'rejected'
    sharePercentage: { type: Number, default: 25 }, // Member yield share percentage (default 25%)
    organizationFund: { type: Number, default: 0 }, // Accumulated 5% Org Share Fund
    createdAt: { type: Date, default: Date.now }
});

const UserSchema = new mongoose.Schema({
    phoneNumber: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    name: { type: String, required: true },
    role: { type: String, default: 'member' }, // 'super_admin', 'admin', 'member'
    organizationId: { type: String, default: 'default_org' },
    savings: { type: Number, default: 0 },
    loan: { type: Number, default: 0 },
    unwithdrawnLoan: { type: Number, default: 0 },
    interest: { type: Number, default: 0 }
});

const TransactionSchema = new mongoose.Schema({
    organizationId: { type: String, default: 'default_org' },
    owner: String,
    title: String,
    date: String,
    amount: Number,
    type: String, // 'deposit' or 'withdrawal'
    timestamp: { type: Date, default: Date.now }
});

const PendingDepositSchema = new mongoose.Schema({
    organizationId: { type: String, default: 'default_org' },
    owner: String,
    ownerName: String,
    amount: Number,
    transactionId: String,
    date: String,
    status: { type: String, default: 'pending' }
});

const PendingLoanSchema = new mongoose.Schema({
    organizationId: { type: String, default: 'default_org' },
    amount: Number,
    interest: Number,
    requestedBy: String,
    requestedByPhone: String,
    receivingAccount: { type: String, default: '' },
    date: String,
    status: { type: String, default: 'pending' }
});

const PendingPayoutSchema = new mongoose.Schema({
    organizationId: { type: String, default: 'default_org' },
    amount: Number,
    requestedBy: String,
    requestedByPhone: String,
    receivingAccount: { type: String, default: '' },
    date: String,
    status: { type: String, default: 'pending' }
});

const PendingRepaymentSchema = new mongoose.Schema({
    organizationId: { type: String, default: 'default_org' },
    owner: String,
    ownerName: String,
    amount: Number,
    transactionId: String,
    date: String,
    status: { type: String, default: 'pending' }
});

const MessageSchema = new mongoose.Schema({
    organizationId: { type: String, default: 'default_org' },
    sender: String,
    receiver: String,
    text: String,
    transactionId: String,
    timestamp: { type: Date, default: Date.now }
});

const LogSchema = new mongoose.Schema({
    organizationId: { type: String, default: 'default_org' },
    title: String,
    desc: String,
    time: String,
    type: String,
    timestamp: { type: Date, default: Date.now }
});

const ConfigSchema = new mongoose.Schema({
    key: String,
    value: Number
});

const NotificationSchema = new mongoose.Schema({
    organizationId: { type: String, default: 'default_org' },
    targetUser: { type: String, required: true },
    title: { type: String, required: true },
    body: { type: String, required: true },
    isRead: { type: Boolean, default: false },
    type: { type: String, default: 'info' },
    timestamp: { type: Date, default: Date.now }
});

// Models
const Organization = mongoose.model('Organization', OrganizationSchema);
const User = mongoose.model('User', UserSchema);
const Transaction = mongoose.model('Transaction', TransactionSchema);
const PendingDeposit = mongoose.model('PendingDeposit', PendingDepositSchema);
const PendingLoan = mongoose.model('PendingLoan', PendingLoanSchema);
const PendingPayout = mongoose.model('PendingPayout', PendingPayoutSchema);
const PendingRepayment = mongoose.model('PendingRepayment', PendingRepaymentSchema);
const Message = mongoose.model('Message', MessageSchema);
const Log = mongoose.model('Log', LogSchema);
const Config = mongoose.model('Config', ConfigSchema);
const Notification = mongoose.model('Notification', NotificationSchema);

async function ensureDefaultOrganization() {
    try {
        const defaultOrg = await Organization.findOne({ code: 'default_org' });
        if (!defaultOrg) {
            await new Organization({
                name: 'Default Village Bank',
                code: 'default_org',
                description: 'Default Main Village Bank Organization',
                expectedMembers: 100,
                contactPerson: 'Platform Owner',
                contactPhone: 'owner',
                adminName: 'Super Admin',
                adminPhone: 'admin',
                status: 'approved'
            }).save();
            console.log('[DB] Created Default Organization (default_org)');
        }
    } catch (e) {
        console.error('Error ensuring default org:', e);
    }
}

async function createNotification(targetUser, title, body, organizationId = 'default_org', type = 'info') {
    try {
        const notif = new Notification({
            organizationId,
            targetUser,
            title,
            body,
            type
        });
        await notif.save();
        return notif;
    } catch (e) {
        console.error('Error creating notification:', e);
    }
}

// Helper for Bank & Management Funds
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

async function getManagementFund() {
    const config = await Config.findOne({ key: 'managementFund' });
    return config ? config.value : 0;
}

async function updateManagementFund(amount) {
    await Config.findOneAndUpdate(
        { key: 'managementFund' },
        { $inc: { value: amount } },
        { upsert: true }
    );
}

// ==================== NOTIFICATION ENDPOINTS ====================

app.get('/api/notifications', async (req, res) => {
    const { phone, role, orgCode } = req.query;
    try {
        let targets = ['all'];
        if (phone) targets.push(phone);
        if (role) targets.push(role);

        let query = {
            isRead: false,
            targetUser: { $in: targets }
        };

        if (orgCode && orgCode !== 'all') {
            query.organizationId = orgCode;
        }

        const notifications = await Notification.find(query).sort({ timestamp: -1 }).limit(50);
        res.json({ success: true, notifications });
    } catch (e) {
        console.error('Fetch Notifications Error:', e);
        res.status(500).json({ success: false, notifications: [] });
    }
});

app.post('/api/notifications/read', async (req, res) => {
    const { ids, phone, role } = req.body;
    try {
        if (ids && ids.length > 0) {
            const objectIds = ids.map(id => {
                try {
                    return new mongoose.Types.ObjectId(id);
                } catch (e) {
                    return id;
                }
            });
            await Notification.updateMany({ _id: { $in: objectIds } }, { $set: { isRead: true } });
        } else if (phone) {
            let targets = ['all', phone];
            if (role) targets.push(role);
            await Notification.updateMany({ targetUser: { $in: targets } }, { $set: { isRead: true } });
        }
        res.json({ success: true });
    } catch (e) {
        console.error('Mark Notifications Read Error:', e);
        res.status(500).json({ success: false });
    }
});

// ==================== ORGANIZATION ENDPOINTS ====================

// Get all approved active organizations (For member registration dropdown)
app.get('/api/organizations/active', async (req, res) => {
    try {
        const orgs = await Organization.find({ status: 'approved' }).sort({ name: 1 });
        const result = await Promise.all(orgs.map(async (org) => {
            const count = await User.countDocuments({ organizationId: org.code });
            return {
                code: org.code,
                name: org.name,
                description: org.description,
                expectedMembers: org.expectedMembers,
                contactPerson: org.contactPerson,
                memberCount: count
            };
        }));
        res.json({ success: true, organizations: result });
    } catch (e) {
        res.status(500).json({ success: false, organizations: [] });
    }
});

// Register a new organization (Sent directly to Management Portal for review)
app.post('/api/organizations/register', async (req, res) => {
    const { name, expectedMembers, contactPerson, contactPhone, contactEmail, description, adminName, adminPhone, adminPassword } = req.body;

    if (!name || !contactPerson || !contactPhone || !adminPhone || !adminPassword) {
        return res.status(400).json({ success: false, message: 'Missing required organization details.' });
    }

    try {
        const existingUser = await User.findOne({ phoneNumber: adminPhone });
        if (existingUser) {
            return res.status(400).json({ success: false, message: 'Admin phone number is already registered in the system.' });
        }

        const slug = name.toLowerCase().replace(/[^a-z0-9]/g, '-').replace(/-+/g, '-').substring(0, 20);
        const uniqueCode = `${slug}-${Math.floor(1000 + Math.random() * 9000)}`;

        const newOrg = new Organization({
            name,
            code: uniqueCode,
            description: description || 'Village Bank Organization',
            expectedMembers: parseInt(expectedMembers) || 10,
            contactPerson,
            contactPhone,
            contactEmail: contactEmail || '',
            adminName: adminName || contactPerson,
            adminPhone,
            status: 'pending'
        });
        await newOrg.save();

        const newAdmin = new User({
            phoneNumber: adminPhone,
            password: adminPassword,
            name: adminName || contactPerson,
            role: 'admin',
            organizationId: uniqueCode
        });
        await newAdmin.save();

        await new Log({
            organizationId: uniqueCode,
            title: 'ORGANIZATION REGISTERED',
            desc: `New Organization '${name}' registered by ${contactPerson}. Pending Management Review.`,
            time: 'Now',
            type: 'warning'
        }).save();

        await createNotification('super_admin', 'New Organization Registered', `New Organization '${name}' registered by ${contactPerson}. Pending Management Review.`, uniqueCode, 'warning');

        res.json({
            success: true,
            message: 'Your organization registration has been submitted to Management. Once approved, your admin account will be activated.'
        });
    } catch (e) {
        console.error('Org Register Error:', e);
        res.status(500).json({ success: false, message: 'Server error registering organization.' });
    }
});

// ==================== MANAGEMENT PORTAL (SITE OWNER) ENDPOINTS ====================

app.get('/api/management/overview', async (req, res) => {
    try {
        const totalOrgs = await Organization.countDocuments({ status: 'approved' });
        const pendingOrgs = await Organization.countDocuments({ status: 'pending' });
        const totalUsers = await User.countDocuments({});
        const allUsers = await User.find({});

        const totalSavings = allUsers.reduce((s, u) => s + (u.savings || 0), 0);
        const totalLoans = allUsers.reduce((s, u) => s + (u.loan || 0), 0);

        res.json({
            success: true,
            totalOrganizations: totalOrgs,
            pendingOrganizationsCount: pendingOrgs,
            totalMembers: totalUsers,
            totalSavings: totalSavings,
            totalLoans: totalLoans,
            groupFund: totalSavings - totalLoans
        });
    } catch (e) {
        res.status(500).json({ success: false });
    }
});

app.get('/api/management/organizations', async (req, res) => {
    try {
        const orgs = await Organization.find({}).sort({ createdAt: -1 });
        const detailedOrgs = await Promise.all(orgs.map(async (org) => {
            const orgUsers = await User.find({ organizationId: org.code });
            const totalSavings = orgUsers.reduce((s, u) => s + (u.savings || 0), 0);
            const totalLoans = orgUsers.reduce((s, u) => s + (u.loan || 0), 0);
            return {
                id: org._id,
                code: org.code,
                name: org.name,
                description: org.description,
                expectedMembers: org.expectedMembers,
                contactPerson: org.contactPerson,
                contactPhone: org.contactPhone,
                contactEmail: org.contactEmail,
                adminName: org.adminName,
                adminPhone: org.adminPhone,
                status: org.status,
                memberCount: orgUsers.length,
                totalSavings: totalSavings,
                totalLoans: totalLoans,
                createdAt: org.createdAt
            };
        }));
        res.json({ success: true, organizations: detailedOrgs });
    } catch (e) {
        res.status(500).json({ success: false, organizations: [] });
    }
});

app.post('/api/management/approve-organization', async (req, res) => {
    const { orgId, approve } = req.body;
    try {
        const org = await Organization.findById(orgId);
        if (!org) return res.status(404).json({ success: false, message: 'Organization not found' });

        org.status = approve ? 'approved' : 'rejected';
        await org.save();

        await new Log({
            organizationId: org.code,
            title: approve ? 'ORGANIZATION APPROVED' : 'ORGANIZATION REJECTED',
            desc: `Organization '${org.name}' status set to ${org.status} by Site Owner.`,
            time: 'Now',
            type: approve ? 'success' : 'danger'
        }).save();

        await createNotification(org.adminPhone || 'admin', 'Organization Status Updated', `Organization '${org.name}' status set to ${org.status} by Management.`, org.code, approve ? 'success' : 'danger');

        res.json({ success: true, status: org.status, message: `Organization ${org.name} has been ${org.status}` });
    } catch (e) {
        res.status(500).json({ success: false });
    }
});

app.get('/api/management/organization-members', async (req, res) => {
    const { orgCode } = req.query;
    try {
        const users = await User.find({ organizationId: orgCode });
        const data = users.map(u => ({
            name: u.name,
            phoneNumber: u.phoneNumber,
            role: u.role,
            savings: u.savings,
            loan: u.loan,
            interest: u.interest || (u.loan * INTEREST_RATE),
            organizationId: u.organizationId
        }));
        res.json({ success: true, members: data });
    } catch (e) {
        res.status(500).json({ success: false, members: [] });
    }
});

// ==================== AUTH ENDPOINTS ====================

app.post('/api/auth/login', async (req, res) => {
    const { phoneNumber, password } = req.body;

    // Site Owner Super Admin Login
    if ((phoneNumber.toLowerCase() === 'owner' || phoneNumber.toLowerCase() === 'superadmin') && password === 'password') {
        return res.json({
            success: true,
            role: 'super_admin',
            token: 'owner-token',
            name: 'Platform Owner',
            organizationId: 'all',
            organizationName: 'Global Management Portal'
        });
    }

    // Default legacy admin login support
    if (phoneNumber.toLowerCase() === 'admin' && password === 'password') {
        const defaultOrg = await Organization.findOne({ code: 'default_org' });
        return res.json({
            success: true,
            role: 'admin',
            token: 'admin-token',
            name: 'Super Admin',
            organizationId: 'default_org',
            organizationName: defaultOrg ? defaultOrg.name : 'Default Village Bank'
        });
    }

    try {
        const user = await User.findOne({ phoneNumber, password });
        if (!user) {
            return res.status(401).json({ success: false, message: 'Invalid phone number or password' });
        }

        const orgCode = user.organizationId || 'default_org';
        const org = await Organization.findOne({ code: orgCode });

        if (org && org.status === 'pending' && user.role !== 'super_admin') {
            return res.status(403).json({
                success: false,
                message: 'Your organization registration is pending approval by Management.'
            });
        }

        if (org && org.status === 'rejected' && user.role !== 'super_admin') {
            return res.status(403).json({
                success: false,
                message: 'Your organization registration was not approved by Management.'
            });
        }

        res.json({
            success: true,
            role: user.role,
            token: user.role === 'admin' ? 'admin-token' : user.phoneNumber,
            name: user.name,
            organizationId: orgCode,
            organizationName: org ? org.name : 'Village Bank'
        });
    } catch (e) {
        res.status(500).json({ success: false, message: 'Login error' });
    }
});

app.post('/api/auth/register', async (req, res) => {
    const { phoneNumber, password, fullName, role, organizationId } = req.body;
    try {
        const existing = await User.findOne({ phoneNumber });
        if (existing) {
            return res.status(400).json({ success: false, message: 'Phone number is already registered.' });
        }

        const orgCode = organizationId || 'default_org';
        const org = await Organization.findOne({ code: orgCode });
        if (!org || org.status !== 'approved') {
            return res.status(400).json({ success: false, message: 'Selected organization is invalid or not active.' });
        }

        const newUser = new User({
            phoneNumber,
            password,
            name: fullName,
            role: role === 'admin' ? 'admin' : 'member',
            organizationId: orgCode
        });
        await newUser.save();

        res.json({
            success: true,
            role: newUser.role,
            token: newUser.role === 'admin' ? 'admin-token' : newUser.phoneNumber,
            name: fullName,
            organizationId: orgCode,
            organizationName: org.name
        });
    } catch (e) {
        res.status(500).json({ success: false, message: 'Server error during registration.' });
    }
});

// ==================== MEMBER ENDPOINTS ====================

app.get('/api/member/summary', async (req, res) => {
    const phone = req.query.phone;
    try {
        const user = await User.findOne({ phoneNumber: phone });
        if (!user) return res.status(404).json({ message: 'User not found' });

        const org = await Organization.findOne({ code: user.organizationId || 'default_org' });
        const adminPhone = org ? (org.adminPhone || org.contactPhone || '0881689220') : '0881689220';
        const sharePercentage = org ? (org.sharePercentage || 25) : 25;

        const pendingLoanCount = await PendingLoan.countDocuments({ requestedByPhone: phone, status: 'pending' });
        const accruedInterest = user.interest !== undefined ? user.interest : (user.loan * INTEREST_RATE);
        res.json({
            savings: user.savings,
            loan: user.loan,
            unwithdrawnLoan: user.unwithdrawnLoan || 0,
            accruedInterest: accruedInterest,
            totalToRepay: user.loan + accruedInterest,
            interestRate: INTEREST_RATE * 100,
            sharePercentage: sharePercentage,
            pendingLoanCount: pendingLoanCount,
            organizationId: user.organizationId,
            adminPhone: adminPhone
        });
    } catch (e) {
        res.status(500).json({ message: 'Error' });
    }
});

app.post('/api/admin/update-account-number', async (req, res) => {
    const { orgCode, adminPhone } = req.body;
    if (!orgCode || !adminPhone) {
        return res.status(400).json({ success: false, message: 'Missing required parameters' });
    }
    try {
        const org = await Organization.findOne({ code: orgCode });
        if (org) {
            org.adminPhone = adminPhone;
            org.contactPhone = adminPhone;
            await org.save();

            await new Log({
                organizationId: orgCode,
                title: 'ACCOUNT NUMBER UPDATED',
                desc: `Organization receiving account number updated to ${adminPhone}.`,
                time: 'Now',
                type: 'info'
            }).save();

            res.json({ success: true, adminPhone: adminPhone, message: 'Organization account number updated successfully' });
        } else {
            res.status(404).json({ success: false, message: 'Organization not found' });
        }
    } catch (e) {
        res.status(500).json({ success: false, message: 'Server error updating account number' });
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
            organizationId: user.organizationId || 'default_org',
            owner: phone,
            ownerName: user.name,
            amount: depositAmount,
            transactionId: transactionId,
            date: new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
        });
        await newPending.save();

        await new Log({
            organizationId: user.organizationId || 'default_org',
            title: 'DEPOSIT SUBMITTED',
            desc: `MK ${depositAmount} submitted by ${user.name} (ID: ${transactionId})`,
            time: 'Now',
            type: 'warning'
        }).save();

        await createNotification('admin', 'New Deposit Submitted', `MK ${depositAmount} deposit submitted by ${user.name}`, user.organizationId || 'default_org', 'warning');

        setTimeout(async () => {
            await new Message({
                organizationId: user.organizationId || 'default_org',
                sender: 'admin-token',
                receiver: phone,
                text: `Hello ${user.name}, I have received your deposit request of MK ${depositAmount}. Please wait for your Organization Admin's verification. Transaction ID: ${transactionId}`
            }).save();
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

        const pendingLoanCount = await PendingLoan.countDocuments({ requestedByPhone: phone, status: 'pending' });
        if (pendingLoanCount >= 3) {
            return res.status(400).json({ success: false, message: 'Loan request limit reached. Maximum 3 active loan requests allowed.' });
        }

        const loanAmount = parseFloat(amount);
        const orgCode = user.organizationId || 'default_org';

        // Check group fund for this organization
        const orgUsers = await User.find({ organizationId: orgCode });
        const totalSavings = orgUsers.reduce((s, u) => s + u.savings, 0);
        const totalLoans = orgUsers.reduce((s, u) => s + u.loan, 0);
        const groupFund = totalSavings - totalLoans;

        if (groupFund < loanAmount) {
            return res.status(400).json({ success: false, message: 'Insufficient organization group funds' });
        }

        const newLoan = new PendingLoan({
            organizationId: orgCode,
            amount: loanAmount,
            interest: loanAmount * INTEREST_RATE,
            requestedBy: user.name,
            requestedByPhone: phone,
            receivingAccount: receivingAccount || '',
            date: new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
        });
        await newLoan.save();

        await new Log({
            organizationId: orgCode,
            title: 'LOAN REQUEST',
            desc: `MK ${loanAmount} requested by ${user.name}`,
            time: 'Now',
            type: 'warning'
        }).save();

        await createNotification('admin', 'New Loan Requested', `MK ${loanAmount} loan requested by ${user.name}`, orgCode, 'warning');

        setTimeout(async () => {
            await new Message({
                organizationId: orgCode,
                sender: 'admin-token',
                receiver: phone,
                text: `Loan request for MK ${loanAmount} received. The request has been forwarded to your Organization Admin for verification and approval.`
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
            organizationId: user.organizationId || 'default_org',
            owner: phone,
            ownerName: user.name,
            amount: repaymentAmount,
            transactionId: transactionId,
            date: new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' })
        });
        await newPending.save();

        await new Log({
            organizationId: user.organizationId || 'default_org',
            title: 'REPAYMENT SUBMITTED',
            desc: `MK ${repaymentAmount} repayment submitted by ${user.name} (ID: ${transactionId})`,
            time: 'Now',
            type: 'warning'
        }).save();

        await createNotification('admin', 'New Repayment Submitted', `MK ${repaymentAmount} loan repayment submitted by ${user.name}`, user.organizationId || 'default_org', 'warning');

        setTimeout(async () => {
            await new Message({
                organizationId: user.organizationId || 'default_org',
                sender: 'admin-token',
                receiver: phone,
                text: `Hello ${user.name}, I have received your loan repayment request of MK ${repaymentAmount}. Please wait for your Organization Admin's verification.`
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
            organizationId: user.organizationId || 'default_org',
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
            organizationId: user.organizationId || 'default_org',
            title: 'PAYOUT REQUEST',
            desc: `MK ${payoutAmount} requested by ${user.name}`,
            time: 'Now',
            type: 'warning'
        }).save();

        await createNotification('admin', 'New Payout Requested', `MK ${payoutAmount} payout requested by ${user.name}`, user.organizationId || 'default_org', 'warning');

        setTimeout(async () => {
            await new Message({
                organizationId: user.organizationId || 'default_org',
                sender: 'admin-token',
                receiver: phone,
                text: `Your payout request for MK ${payoutAmount} is being processed. Please wait for your Organization Admin's verification.`
            }).save();
        }, 1000);

        res.json({ success: true, payout: newPayout });
    } catch (e) {
        res.status(500).json({ success: false });
    }
});

// ==================== ADMIN ENDPOINTS (ORGANIZATION ADMIN) ====================

app.get('/api/admin/overview', async (req, res) => {
    const orgCode = req.query.orgCode || 'default_org';
    try {
        let userFilter = orgCode === 'all' ? {} : { organizationId: orgCode };
        let pendingFilter = orgCode === 'all' ? { status: 'pending' } : { organizationId: orgCode, status: 'pending' };

        const users = await User.find(userFilter);
        const pLoans = await PendingLoan.countDocuments(pendingFilter);
        const pPayouts = await PendingPayout.countDocuments(pendingFilter);
        const pDeposits = await PendingDeposit.countDocuments(pendingFilter);
        const pRepayments = await PendingRepayment.countDocuments(pendingFilter);

        const totalSavings = users.reduce((s, u) => s + u.savings, 0);
        const totalLoans = users.reduce((s, u) => s + u.loan, 0);
        const bankFund = await getBankFund();

        const savingsValues = users.map(u => u.savings);
        const highestNet = savingsValues.length > 0 ? Math.max(...savingsValues) : 0;

        const org = await Organization.findOne({ code: orgCode === 'all' ? 'default_org' : orgCode });
        const sharePercentage = org ? (org.sharePercentage !== undefined ? org.sharePercentage : 25) : 25;

        res.json({
            totalMembers: users.length,
            groupFund: totalSavings - totalLoans,
            totalLoans: totalLoans,
            pendingApprovals: pLoans + pRepayments,
            pendingPayouts: pPayouts,
            pendingDeposits: pDeposits,
            pendingRepayments: pRepayments,
            highestNet: highestNet,
            bankCommission: bankFund,
            sharePercentage: sharePercentage
        });
    } catch (e) {
        res.status(500).json({});
    }
});

app.get('/api/admin/pending-deposits', async (req, res) => {
    const orgCode = req.query.orgCode;
    const filter = orgCode && orgCode !== 'all' ? { organizationId: orgCode, status: 'pending' } : { status: 'pending' };
    const data = await PendingDeposit.find(filter);
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
                    organizationId: user.organizationId || 'default_org',
                    owner: user.phoneNumber,
                    title: 'Deposit Verified',
                    date: deposit.date,
                    amount: deposit.amount,
                    type: 'deposit'
                }).save();

                await new Log({
                    organizationId: user.organizationId || 'default_org',
                    title: 'DEPOSIT VERIFIED',
                    desc: `MK ${deposit.amount} for ${user.name} approved.`,
                    time: 'Now',
                    type: 'success'
                }).save();

                await createNotification(deposit.owner, 'Deposit Approved', `Your deposit of MK ${deposit.amount} has been verified and credited to your savings.`, deposit.organizationId || 'default_org', 'success');
            }
        } else {
            await createNotification(deposit.owner, 'Deposit Rejected', `Your deposit of MK ${deposit.amount} was rejected.`, deposit.organizationId || 'default_org', 'danger');
        }
        await PendingDeposit.findByIdAndDelete(depositId);
        res.json({ success: true });
    } catch (e) {
        res.status(500).json({ success: false });
    }
});

app.get('/api/admin/pending-payouts', async (req, res) => {
    const orgCode = req.query.orgCode;
    const filter = orgCode && orgCode !== 'all' ? { organizationId: orgCode, status: 'pending' } : { status: 'pending' };
    const data = await PendingPayout.find(filter);
    res.json(data);
});

app.post('/api/admin/process-payout', async (req, res) => {
    const { payoutId, confirm } = req.body;
    try {
        const payout = await PendingPayout.findById(payoutId);
        if (!payout) return res.status(404).json({ success: false });

        if (confirm) {
            await new Transaction({
                organizationId: payout.organizationId || 'default_org',
                owner: payout.requestedByPhone,
                title: 'Payout Disbursed to SIM',
                date: new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
                amount: payout.amount,
                type: 'withdrawal'
            }).save();

            await createNotification(payout.requestedByPhone, 'Payout Disbursed', `Your payout request of MK ${payout.amount} has been disbursed to ${payout.receivingAccount || payout.requestedByPhone}.`, payout.organizationId || 'default_org', 'success');

            await PendingPayout.findByIdAndDelete(payoutId);
            return res.json({ success: true, phone: payout.receivingAccount || payout.requestedByPhone, amount: payout.amount });
        } else {
            const user = await User.findOne({ phoneNumber: payout.requestedByPhone });
            if (user) {
                user.savings += payout.amount;
                await user.save();
            }

            await createNotification(payout.requestedByPhone, 'Payout Rejected', `Your payout request of MK ${payout.amount} was rejected. Savings restored.`, payout.organizationId || 'default_org', 'danger');
        }
        await PendingPayout.findByIdAndDelete(payoutId);
        res.json({ success: true });
    } catch (e) {
        res.status(500).json({ success: false });
    }
});

app.get('/api/admin/pending-loans', async (req, res) => {
    const orgCode = req.query.orgCode;
    const filter = orgCode && orgCode !== 'all' ? { organizationId: orgCode, status: 'pending' } : { status: 'pending' };
    const data = await PendingLoan.find(filter);
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
                user.unwithdrawnLoan = (user.unwithdrawnLoan || 0) + loan.amount;
                user.interest = (user.interest || 0) + (loan.amount * INTEREST_RATE);
                await user.save();

                await new Transaction({
                    organizationId: user.organizationId || 'default_org',
                    owner: user.phoneNumber,
                    title: 'Loan Approved (Credited to Wallet)',
                    date: new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
                    amount: loan.amount,
                    type: 'deposit'
                }).save();

                await createNotification(loan.requestedByPhone, 'Loan Approved', `Your loan request of MK ${loan.amount} has been approved and credited to your wallet.`, loan.organizationId || 'default_org', 'success');

                await PendingLoan.findByIdAndDelete(loanId);
                return res.json({ success: true, phone: loan.receivingAccount || user.phoneNumber, amount: loan.amount });
            }
        } else {
            await createNotification(loan.requestedByPhone, 'Loan Rejected', `Your loan request of MK ${loan.amount} was rejected.`, loan.organizationId || 'default_org', 'danger');
        }
        await PendingLoan.findByIdAndDelete(loanId);
        res.json({ success: true });
    } catch (e) {
        res.status(500).json({ success: false });
    }
});

// Instant Loan Withdrawal Endpoint (No Admin Approval Required)
app.post('/api/member/instant-withdraw-loan', async (req, res) => {
    const { phone, amount, paymentMethod, receivingPhone } = req.body;
    try {
        const user = await User.findOne({ phoneNumber: phone });
        if (!user) return res.status(404).json({ success: false, message: 'User not found' });

        const withdrawAmount = parseFloat(amount);
        if (isNaN(withdrawAmount) || withdrawAmount <= 0) {
            return res.status(400).json({ success: false, message: 'Invalid withdrawal amount.' });
        }

        const currentUnwithdrawn = user.unwithdrawnLoan || 0;
        if (currentUnwithdrawn < withdrawAmount) {
            return res.status(400).json({
                success: false,
                message: `Insufficient unwithdrawn loaned cash. Available: MK ${currentUnwithdrawn.toFixed(2)}`
            });
        }

        user.unwithdrawnLoan = currentUnwithdrawn - withdrawAmount;
        await user.save();

        const targetAccount = receivingPhone || phone;
        const method = paymentMethod || 'Mobile Money';

        await new Transaction({
            organizationId: user.organizationId || 'default_org',
            owner: user.phoneNumber,
            title: `Instant Withdrawal (${method}: ${targetAccount})`,
            date: new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' }),
            amount: withdrawAmount,
            type: 'withdrawal'
        }).save();

        await new Log({
            organizationId: user.organizationId || 'default_org',
            title: 'INSTANT LOAN WITHDRAWAL',
            desc: `MK ${withdrawAmount.toFixed(2)} instantly withdrawn by ${user.name} to ${method} (${targetAccount}). No admin approval required.`,
            time: 'Now',
            type: 'success'
        }).save();

        res.json({
            success: true,
            message: `MK ${withdrawAmount.toFixed(2)} has been instantly transferred to ${targetAccount} via ${method}.`,
            remainingUnwithdrawn: user.unwithdrawnLoan
        });
    } catch (e) {
        console.error('Instant Withdraw Error:', e);
        res.status(500).json({ success: false, message: 'Server error processing instant withdrawal.' });
    }
});

app.get('/api/admin/pending-repayments', async (req, res) => {
    const orgCode = req.query.orgCode;
    const filter = orgCode && orgCode !== 'all' ? { organizationId: orgCode, status: 'pending' } : { status: 'pending' };
    const data = await PendingRepayment.find(filter);
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

                // Fetch user's organization share configuration
                const orgCode = user.organizationId || 'default_org';
                const org = await Organization.findOne({ code: orgCode });

                // Organization share rate (default 25%)
                const sharePercentage = (org && org.sharePercentage) ? org.sharePercentage : 25;

                const memberProfit = principal * (sharePercentage / 100);
                const orgCut = principal * 0.05; // 5% Organization Reserve Share
                const managementCut = principal * 0.05; // 5% Main Management Portal Share

                await new Transaction({
                    organizationId: orgCode,
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

                // Allocate 5% to Organization Reserve Fund
                if (org) {
                    org.organizationFund = (org.organizationFund || 0) + orgCut;
                    await org.save();
                }

                // Allocate 5% to Main Management Portal Pool
                await updateManagementFund(managementCut);
                await updateBankFund(orgCut); // Keep bank fund updated

                await new Log({
                    organizationId: orgCode,
                    title: 'REPAYMENT VERIFIED',
                    desc: `MK ${repayment.amount.toFixed(2)} repaid by ${user.name}. Allocated ${sharePercentage}% to Member, 5% to Org Reserve, 5% to Platform Management.`,
                    time: 'Now',
                    type: 'success'
                }).save();

                await createNotification(repayment.owner, 'Loan Repayment Approved', `Your loan repayment of MK ${repayment.amount} has been verified and cleared.`, orgCode, 'success');
            }
        } else {
            await createNotification(repayment.owner, 'Loan Repayment Rejected', `Your loan repayment of MK ${repayment.amount} was rejected.`, repayment.organizationId || 'default_org', 'danger');
        }
        await PendingRepayment.findByIdAndDelete(repaymentId);
        res.json({ success: true });
    } catch (e) {
        console.error('Approve Repayment Error:', e);
        res.status(500).json({ success: false });
    }
});

// Update Organization Share Percentage (Org Admin or Super Admin)
app.post('/api/organizations/set-share-percentage', async (req, res) => {
    const { orgCode, sharePercentage } = req.body;
    try {
        const share = parseFloat(sharePercentage);
        if (isNaN(share) || share < 0 || share > 50) {
            return res.status(400).json({ success: false, message: 'Share percentage must be between 0% and 50%.' });
        }

        const org = await Organization.findOne({ code: orgCode });
        if (!org) return res.status(404).json({ success: false, message: 'Organization not found.' });

        org.sharePercentage = share;
        await org.save();

        await new Log({
            organizationId: orgCode,
            title: 'SHARE RATE UPDATED',
            desc: `Organization member share percentage set to ${share}%. (Guaranteed 5% Org Reserve + 5% Management Portal Share).`,
            time: 'Now',
            type: 'info'
        }).save();

        res.json({ success: true, sharePercentage: org.sharePercentage, message: `Member share percentage updated to ${share}%` });
    } catch (e) {
        res.status(500).json({ success: false, message: 'Error updating share percentage' });
    }
});

// ==================== GLOBAL ANALYSIS ENDPOINTS ====================

app.get('/api/analytics/global', async (req, res) => {
    try {
        const approvedOrgs = await Organization.find({ status: 'approved' }).sort({ name: 1 });
        const allUsers = await User.find({});

        let platformTotalSavings = 0;
        let platformTotalLoans = 0;

        const orgsData = await Promise.all(approvedOrgs.map(async (org) => {
            const orgUsers = allUsers.filter(u => u.organizationId === org.code);
            const totalSavings = orgUsers.reduce((s, u) => s + (u.savings || 0), 0);
            const totalLoans = orgUsers.reduce((s, u) => s + (u.loan || 0), 0);

            platformTotalSavings += totalSavings;
            platformTotalLoans += totalLoans;

            const fundUtilization = totalSavings > 0 ? Math.min(100, Math.round((totalLoans / totalSavings) * 100)) : 0;
            const healthScore = totalSavings > 0 ? Math.min(100, Math.round(((totalSavings - totalLoans) / totalSavings) * 100)) : 100;

            return {
                code: org.code,
                name: org.name,
                description: org.description,
                contactPerson: org.contactPerson,
                memberCount: orgUsers.length,
                totalSavings: totalSavings,
                totalLoans: totalLoans,
                fundUtilization: fundUtilization,
                healthScore: healthScore,
                organizationFund: org.organizationFund || 0,
                sharePercentage: org.sharePercentage || 25,
                createdAt: org.createdAt
            };
        }));

        const managementFund = await getManagementFund();

        res.json({
            success: true,
            summary: {
                totalOrganizations: approvedOrgs.length,
                totalMembers: allUsers.length,
                platformTotalSavings: platformTotalSavings,
                platformTotalLoans: platformTotalLoans,
                platformManagementFund: managementFund,
                netPool: platformTotalSavings - platformTotalLoans
            },
            organizations: orgsData
        });
    } catch (e) {
        console.error('Global Analytics Error:', e);
        res.status(500).json({ success: false, summary: null, organizations: [] });
    }
});

app.get('/api/admin/logs', async (req, res) => {
    const orgCode = req.query.orgCode;
    const filter = orgCode && orgCode !== 'all' ? { organizationId: orgCode } : {};
    const logs = await Log.find(filter).sort({ timestamp: -1 }).limit(50);
    res.json(logs);
});

app.get('/api/admin/users', async (req, res) => {
    const orgCode = req.query.orgCode;
    const filter = orgCode && orgCode !== 'all' ? { organizationId: orgCode } : {};
    const users = await User.find(filter);
    const data = users.map(u => ({
        name: u.name,
        phoneNumber: u.phoneNumber,
        role: u.role,
        savings: u.savings,
        loan: u.loan,
        interest: u.interest || (u.loan * INTEREST_RATE),
        organizationId: u.organizationId
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
    await Organization.deleteMany({});
    await Notification.deleteMany({});

    await ensureDefaultOrganization();

    await new Log({
        organizationId: 'default_org',
        title: 'SYSTEM RESET',
        desc: 'All system data reset by Admin.',
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
    const { sender, receiver, text, transactionId, organizationId } = req.body;
    try {
        const newMessage = new Message({
            organizationId: organizationId || 'default_org',
            sender,
            receiver,
            text,
            transactionId
        });
        await newMessage.save();

        await createNotification(receiver, 'New Chat Message', text || 'New message received', organizationId || 'default_org', 'info');

        res.json(newMessage);
    } catch (e) {
        res.status(500).json({ success: false });
    }
});

// PayChangu Direct Mobile Money Payment (Deposit / Repayment)
app.post('/api/paychangu/charge-mobile-money', async (req, res) => {
    const { phone, amount, paymentMethod, type = 'deposit', pin } = req.body;

    if (!amount || !phone) {
        return res.status(400).json({ success: false, message: 'Amount and phone number are required.' });
    }

    try {
        const user = await User.findOne({ phoneNumber: phone });
        if (!user) return res.status(404).json({ success: false, message: 'User not found.' });

        const payAmount = parseFloat(amount);
        if (isNaN(payAmount) || payAmount <= 0) {
            return res.status(400).json({ success: false, message: 'Invalid payment amount.' });
        }

        const tx_ref = `VB-PC-${type.toUpperCase()}-${Date.now()}`;
        const operator = (paymentMethod || '').toLowerCase().includes('airtel') ? 'AIRTEL' : 'TNM';

        let payChanguSuccess = true;
        let responseData = null;

        if (PAYCHANGU_SECRET_KEY !== 'sec_key_placeholder') {
            const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));
            const payChanguRes = await fetch('https://api.paychangu.com/mobile-money/payments', {
                method: 'POST',
                headers: {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${PAYCHANGU_SECRET_KEY}`
                },
                body: JSON.stringify({
                    amount: payAmount,
                    currency: 'MWK',
                    email: user.email || `${phone}@villagebank.app`,
                    first_name: user.name ? user.name.split(' ')[0] : 'Member',
                    last_name: user.name ? (user.name.split(' ')[1] || 'User') : 'Member',
                    mobile: phone,
                    mobile_money_operator_ref_id: operator,
                    charge_id: tx_ref
                })
            });
            responseData = await payChanguRes.json();
            if (responseData.status !== 'success' && responseData.status !== 'successful' && !payChanguRes.ok) {
                payChanguSuccess = false;
            }
        }

        if (!payChanguSuccess) {
            return res.status(400).json({
                success: false,
                message: responseData?.message || 'Mobile Money transaction failed. Check phone or PIN.'
            });
        }

        const dateStr = new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' });

        if (type === 'deposit') {
            user.savings = (user.savings || 0) + payAmount;
            await user.save();

            await new Transaction({
                organizationId: user.organizationId || 'default_org',
                owner: user.phoneNumber,
                title: `Instant Deposit (${paymentMethod || operator})`,
                date: dateStr,
                amount: payAmount,
                type: 'deposit'
            }).save();

            await new Log({
                organizationId: user.organizationId || 'default_org',
                title: 'INSTANT DEPOSIT VERIFIED',
                desc: `MK ${payAmount.toFixed(2)} credited to ${user.name} via Direct Gateway (${paymentMethod || operator})`,
                time: 'Now',
                type: 'success'
            }).save();

            await createNotification(
                user.phoneNumber,
                'Deposit Confirmed',
                `Your deposit of MK ${payAmount.toFixed(2)} via Direct Gateway was processed successfully!`,
                user.organizationId || 'default_org',
                'success'
            );

            return res.json({
                success: true,
                message: `MK ${payAmount.toFixed(2)} deposited successfully into your savings!`,
                newSavings: user.savings
            });

        } else if (type === 'repayment') {
            const orgCode = user.organizationId || 'default_org';
            let orgSharePerc = 0;
            const org = await Organization.findOne({ code: orgCode });
            if (org && org.sharePercentage !== undefined) {
                orgSharePerc = org.sharePercentage;
            }

            const currentInterest = user.accruedInterest || 0;
            const currentPrincipal = user.loan || 0;

            let interestPaid = 0;
            let principalPaid = 0;

            if (payAmount <= currentInterest) {
                interestPaid = payAmount;
                user.accruedInterest = currentInterest - payAmount;
            } else {
                interestPaid = currentInterest;
                user.accruedInterest = 0;
                principalPaid = payAmount - currentInterest;
                user.loan = Math.max(0, currentPrincipal - principalPaid);
            }

            await user.save();

            if (orgSharePerc > 0 && interestPaid > 0) {
                const totalInterestShares = (interestPaid * orgSharePerc) / 100;
                const members = await User.find({ organizationId: orgCode });
                if (members.length > 0) {
                    const sharePerMember = totalInterestShares / members.length;
                    for (const m of members) {
                        m.savings = (m.savings || 0) + sharePerMember;
                        await m.save();
                    }
                }
            }

            await new Transaction({
                organizationId: orgCode,
                owner: user.phoneNumber,
                title: `Loan Repayment (${paymentMethod || operator})`,
                date: dateStr,
                amount: payAmount,
                type: 'deposit'
            }).save();

            await new Log({
                organizationId: orgCode,
                title: 'INSTANT REPAYMENT VERIFIED',
                desc: `MK ${payAmount.toFixed(2)} loan repayment by ${user.name} processed via Direct Gateway.`,
                time: 'Now',
                type: 'success'
            }).save();

            await createNotification(
                user.phoneNumber,
                'Loan Repayment Confirmed',
                `Your loan repayment of MK ${payAmount.toFixed(2)} via Direct Gateway was successful!`,
                orgCode,
                'success'
            );

            return res.json({
                success: true,
                message: `MK ${payAmount.toFixed(2)} loan repayment processed successfully!`,
                remainingLoan: user.loan,
                remainingInterest: user.accruedInterest
            });
        } else {
            return res.status(400).json({ success: false, message: 'Invalid payment type.' });
        }

    } catch (e) {
        console.error('Mobile Money Charge Error:', e);
        res.status(500).json({ success: false, message: 'Server error processing Mobile Money payment.' });
    }
});

// Automated Direct Payout / Disbursement
app.post('/api/paychangu/payout', async (req, res) => {
    const { amount, recipientPhone, paymentMethod, phone, type = 'payout' } = req.body;

    if (!amount || !recipientPhone || !phone) {
        return res.status(400).json({ success: false, message: 'Amount, phone, and recipient phone required.' });
    }

    try {
        const user = await User.findOne({ phoneNumber: phone });
        if (!user) return res.status(404).json({ success: false, message: 'User not found.' });

        const payoutAmount = parseFloat(amount);
        if (isNaN(payoutAmount) || payoutAmount <= 0) {
            return res.status(400).json({ success: false, message: 'Invalid withdrawal amount.' });
        }

        if (type === 'instant-loan') {
            const availableLoan = user.unwithdrawnLoan || 0;
            if (payoutAmount > availableLoan) {
                return res.status(400).json({ success: false, message: `Insufficient unwithdrawn loan. Available: MK ${availableLoan.toFixed(2)}` });
            }
            user.unwithdrawnLoan = availableLoan - payoutAmount;
        } else {
            const availableSavings = user.savings || 0;
            if (payoutAmount > availableSavings) {
                return res.status(400).json({ success: false, message: `Insufficient savings balance. Available: MK ${availableSavings.toFixed(2)}` });
            }
            user.savings = availableSavings - payoutAmount;
        }

        await user.save();

        const operator = recipientPhone.startsWith('088') || recipientPhone.startsWith('031') || (paymentMethod || '').toLowerCase().includes('tnm') ? 'TNM' : 'AIRTEL';
        const payout_ref = `VB-PO-${Date.now()}-${recipientPhone}`;

        if (PAYCHANGU_SECRET_KEY !== 'sec_key_placeholder') {
            const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));
            const payChanguRes = await fetch('https://api.paychangu.com/mobile-money/disbursements', {
                method: 'POST',
                headers: {
                    'Accept': 'application/json',
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${PAYCHANGU_SECRET_KEY}`
                },
                body: JSON.stringify({
                    amount: payoutAmount,
                    currency: 'MWK',
                    mobile: recipientPhone,
                    mobile_money_operator: operator,
                    charge_id: payout_ref
                })
            });
            const data = await payChanguRes.json();
            console.log('Mobile Money Disbursement Result:', data);
        }

        const dateStr = new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric' });

        await new Transaction({
            organizationId: user.organizationId || 'default_org',
            owner: user.phoneNumber,
            title: `Instant Payout (${operator}: ${recipientPhone})`,
            date: dateStr,
            amount: payoutAmount,
            type: 'withdrawal'
        }).save();

        await new Log({
            organizationId: user.organizationId || 'default_org',
            title: 'INSTANT DISBURSEMENT EXECUTED',
            desc: `MK ${payoutAmount.toFixed(2)} sent to ${recipientPhone} via Direct Gateway (${operator}) for ${user.name}`,
            time: 'Now',
            type: 'info'
        }).save();

        await createNotification(
            user.phoneNumber,
            'Payout Disbursed',
            `MK ${payoutAmount.toFixed(2)} sent to ${recipientPhone} via Direct Gateway (${operator})`,
            user.organizationId || 'default_org',
            'info'
        );

        res.json({
            success: true,
            payout_ref,
            message: `MK ${payoutAmount.toFixed(2)} successfully disbursed to ${recipientPhone} (${operator})!`
        });
    } catch (e) {
        console.error('Payout Error:', e);
        res.status(500).json({ success: false, message: 'Server error processing payout disbursement.' });
    }
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://localhost:${PORT}`);
});
