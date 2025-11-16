//
//  server.js
//  SkillTrade
//
//  Created by Czeglédi Ádi on 10/26/25.
//

const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
const path = require('path');
const { OAuth2Client } = require('google-auth-library');
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || 'your-google-client-id';
const googleClient = new OAuth2Client(GOOGLE_CLIENT_ID);
const app = express();

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' })); // ← Növeld meg 50MB-ra
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// SQLite adatbázis
const DB_PATH = path.join(__dirname, 'skilltrade.db');
const db = new sqlite3.Database(DB_PATH);

// Adatbázis inicializálás
db.serialize(() => {
    // Users tábla létrehozása
    db.run(`CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        username TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        age INTEGER NOT NULL,
        bio TEXT DEFAULT '',
        rating REAL DEFAULT 0.0,
        location_city TEXT DEFAULT '',
        location_country TEXT DEFAULT '',
        skills TEXT DEFAULT '[]',
        pricing TEXT DEFAULT '[]',
        isVerified BOOLEAN DEFAULT 0,
        servicesOffered TEXT DEFAULT '',
        servicesAdvertised TEXT DEFAULT '',
        userRole TEXT DEFAULT 'client',
        status TEXT DEFAULT 'active',
        phoneNumber TEXT,
        address TEXT,
        profileImageUrl TEXT,
        profileImageData TEXT,
        photos TEXT DEFAULT '[]',
        xp INTEGER DEFAULT 0,
        permanentQRCodeUrl TEXT,
        typeofservice TEXT,
        price REAL DEFAULT 0.0,
        googleId TEXT UNIQUE,
        appleId TEXT UNIQUE,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
        updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);

    console.log('✅ SQLite adatbázis inicializálva');
});

// JWT konfiguráció
const JWT_SECRET = process.env.JWT_SECRET || 'skilltrade-sqlite-secret-123';

// Helper függvények
const userToObject = (row) => {
    return {
        _id: row.id.toString(),
        name: row.name,
        email: row.email,
        username: row.username,
        age: row.age,
        bio: row.bio || '',
        rating: row.rating || 0.0,
        location: {
            city: row.location_city || '',
            country: row.location_country || ''
        },
        skills: JSON.parse(row.skills || '[]'),
        pricing: JSON.parse(row.pricing || '[]'),
        isVerified: Boolean(row.isVerified),
        servicesOffered: row.servicesOffered || '',
        servicesAdvertised: row.servicesAdvertised || '',
        userRole: row.userRole || 'client',
        status: row.status || 'active',
        phoneNumber: row.phoneNumber,
        address: row.address ? JSON.parse(row.address) : null,
        profileImageUrl: row.profileImageUrl,
        profileImageData: row.profileImageData,
        photos: JSON.parse(row.photos || '[]'),
        xp: row.xp || 0,
        permanentQRCodeUrl: row.permanentQRCodeUrl,
        typeofservice: row.typeofservice,
        price: row.price || 0.0,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt
    };
};


// Kártya tábla létrehozása
db.run(`CREATE TABLE IF NOT EXISTS payment_cards (
    id TEXT PRIMARY KEY,
    userId TEXT NOT NULL,
    cardName TEXT NOT NULL,
    cardNumber TEXT NOT NULL,
    cardHolderName TEXT NOT NULL,
    expirationMonth INTEGER NOT NULL,
    expirationYear INTEGER NOT NULL,
    cvv TEXT NOT NULL,
    cardType TEXT NOT NULL,
    isDefault BOOLEAN DEFAULT 0,
    lastFourDigits TEXT NOT NULL,
    color TEXT DEFAULT 'blue',
    createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (userId) REFERENCES users(id)
)`);

console.log('✅ Payment cards tábla inicializálva');

// ÚJ KÁRTYA HOZZÁADÁSA
app.post('/api/payment/cards', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        const {
            cardNumber,
            cardHolderName,
            expirationMonth,
            expirationYear,
            cvv,
            isDefault
        } = req.body;

        console.log('💳 Új kártya hozzáadása kérés');

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            const userId = decoded.id;
            
            // Validáció
            if (!cardNumber || !cardHolderName || !expirationMonth || !expirationYear || !cvv) {
                return res.status(400).json({ message: 'Minden mező kitöltése kötelező' });
            }

            // Kártya típus detektálás
            const cardType = detectCardType(cardNumber);
            const lastFourDigits = cardNumber.slice(-4);
            const cardId = uuidv4();
            const cardName = `${cardType} •••• ${lastFourDigits}`;

            // Alapértelmezett kártya beállítása
            if (isDefault) {
                // Először állítsuk vissza az összes kártyát
                db.run(
                    'UPDATE payment_cards SET isDefault = 0 WHERE userId = ?',
                    [userId],
                    function(err) {
                        if (err) {
                            console.error('Default card reset error:', err);
                        }
                        insertNewCard();
                    }
                );
            } else {
                insertNewCard();
            }

            function insertNewCard() {
                // Új kártya beszúrása
                const stmt = db.prepare(`
                    INSERT INTO payment_cards (
                        id, userId, cardName, cardNumber, cardHolderName,
                        expirationMonth, expirationYear, cvv, cardType,
                        isDefault, lastFourDigits
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                `);

                stmt.run(
                    cardId,
                    userId,
                    cardName,
                    cardNumber,
                    cardHolderName,
                    expirationMonth,
                    expirationYear,
                    cvv,
                    cardType,
                    isDefault ? 1 : 0,
                    lastFourDigits,
                    function(err) {
                        if (err) {
                            console.error('Insert card error:', err);
                            return res.status(500).json({ message: 'Hiba a kártya mentésekor' });
                        }

                        console.log('✅ Kártya sikeresen hozzáadva:', cardId);
                        
                        res.status(201).json({
                            message: 'Kártya sikeresen hozzáadva',
                            cardId: cardId
                        });
                    }
                );

                stmt.finalize();
            }
        });

    } catch (error) {
        console.error('Add card error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

// KÁRTYA TÖRLÉSE
app.delete('/api/payment/cards/:cardId', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        const { cardId } = req.params;

        console.log('🗑️ Kártya törlés kérés:', cardId);

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            const userId = decoded.id;

            // Ellenőrizzük, hogy a kártya a felhasználóé-e
            db.get(
                'SELECT id, isDefault FROM payment_cards WHERE id = ? AND userId = ?',
                [cardId, userId],
                (err, card) => {
                    if (err) {
                        console.error('❌ Adatbázis hiba:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    if (!card) {
                        console.log('❌ Kártya nem található:', cardId);
                        return res.status(404).json({ message: 'Kártya nem található' });
                    }

                    console.log('✅ Kártya megtalálva, törlés...');

                    // Töröljük a kártyát
                    db.run(
                        'DELETE FROM payment_cards WHERE id = ? AND userId = ?',
                        [cardId, userId],
                        function(err) {
                            if (err) {
                                console.error('❌ Törlési hiba:', err);
                                return res.status(500).json({ message: 'Hiba a kártya törlésekor' });
                            }

                            console.log('✅ Kártya törölve, changes:', this.changes);

                            // Ha az alapértelmezett kártyát töröltük, állítsunk be egy újat
                            if (card.isDefault) {
                                console.log('🔁 Alapértelmezett kártya törölve, új beállítása...');
                                db.get(
                                    'SELECT id FROM payment_cards WHERE userId = ? LIMIT 1',
                                    [userId],
                                    (err, firstCard) => {
                                        if (firstCard) {
                                            db.run(
                                                'UPDATE payment_cards SET isDefault = 1 WHERE id = ?',
                                                [firstCard.id],
                                                function(err) {
                                                    if (err) {
                                                        console.error('❌ Alapértelmezett kártya beállítási hiba:', err);
                                                    } else {
                                                        console.log('✅ Új alapértelmezett kártya beállítva:', firstCard.id);
                                                    }
                                                }
                                            );
                                        }
                                    }
                                );
                            }

                            console.log('✅ Kártya sikeresen törölve:', cardId);
                            
                            res.status(200).json({
                                message: 'Kártya sikeresen törölve',
                                cardId: cardId
                            });
                        }
                    );
                }
            );
        });

    } catch (error) {
        console.error('❌ Törlési hiba:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

// Add hozzá a server.js-hez - DEBUG endpoint
app.get('/api/payment/cards/debug/:cardId', (req, res) => {
    try {
        const { cardId } = req.params;
        const token = req.headers.authorization?.split(' ')[1];

        console.log('🔍 Kártya debug kérés:', cardId);

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            const userId = decoded.id;

            // Ellenőrizzük az összes kártyát a felhasználóhoz
            db.all(
                'SELECT * FROM payment_cards WHERE userId = ?',
                [userId],
                (err, cards) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    console.log('📋 Felhasználó kártyái:', cards);
                    
                    // Keresd meg a specifikus kártyát
                    const targetCard = cards.find(card => card.id === cardId);
                    
                    res.status(200).json({
                        allCards: cards,
                        targetCard: targetCard,
                        targetCardExists: !!targetCard,
                        cardCount: cards.length
                    });
                }
            );
        });

    } catch (error) {
        console.error('Debug error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});
// ALAPÉRTELMEZETT KÁRTYA BEÁLLÍTÁSA
app.put('/api/payment/cards/:cardId/default', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        const { cardId } = req.params;

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            const userId = decoded.id;

            // Először állítsuk vissza az összes kártyát
            db.run(
                'UPDATE payment_cards SET isDefault = 0 WHERE userId = ?',
                [userId],
                function(err) {
                    if (err) {
                        console.error('Reset default cards error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    // Most állítsuk be az újat
                    db.run(
                        'UPDATE payment_cards SET isDefault = 1 WHERE id = ? AND userId = ?',
                        [cardId, userId],
                        function(err) {
                            if (err) {
                                console.error('Set default card error:', err);
                                return res.status(500).json({ message: 'Hiba az alapértelmezett kártya beállításakor' });
                            }

                            if (this.changes === 0) {
                                return res.status(404).json({ message: 'Kártya nem található' });
                            }

                            console.log('✅ Alapértelmezett kártya beállítva:', cardId);
                            
                            res.status(200).json({
                                message: 'Alapértelmezett kártya sikeresen beállítva',
                                cardId: cardId
                            });
                        }
                    );
                }
            );
        });

    } catch (error) {
        console.error('Set default card error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

// FELHASZNÁLÓ KÁRTYÁINAK LEKÉRÉSE
app.get('/api/payment/cards', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            const userId = decoded.id;

            db.all(
                'SELECT * FROM payment_cards WHERE userId = ? ORDER BY isDefault DESC, createdAt DESC',
                [userId],
                (err, rows) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    const cards = rows.map(row => ({
                        id: row.id,
                        cardName: row.cardName,
                        cardNumber: row.cardNumber,
                        cardHolderName: row.cardHolderName,
                        expirationMonth: row.expirationMonth,
                        expirationYear: row.expirationYear,
                        cvv: row.cvv,
                        cardType: row.cardType,
                        isDefault: Boolean(row.isDefault),
                        lastFourDigits: row.lastFourDigits,
                        color: row.color || 'blue',
                        createdAt: row.createdAt,
                        updatedAt: row.updatedAt
                    }));

                    res.status(200).json({
                        cards: cards,
                        count: cards.length
                    });
                }
            );
        });

    } catch (error) {
        console.error('Get cards error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

// Kártya típus detektálás helper function
function detectCardType(cardNumber) {
    const cleaned = cardNumber.replace(/\s/g, '');
    
    if (/^4[0-9]{12}(?:[0-9]{3})?$/.test(cleaned)) {
        return 'visa';
    } else if (/^5[1-5][0-9]{14}$/.test(cleaned)) {
        return 'mastercard';
    } else if (/^3[47][0-9]{13}$/.test(cleaned)) {
        return 'amex';
    } else if (/^6(?:011|5[0-9]{2})[0-9]{12}$/.test(cleaned)) {
        return 'discover';
    } else {
        return 'unknown';
    }
}
// Routes

// server.js - Add hozzá ezt a route-ot a Google login után

// APPLE BEJELENTKEZÉS
app.post('/api/auth/apple', async (req, res) => {
    try {
        const { identityToken, userIdentifier, email, fullName } = req.body;

        console.log('🔐 Apple login request received');

        if (!identityToken || !userIdentifier) {
            return res.status(400).json({
                message: 'Apple token hiányzik'
            });
        }

        // Itt kellene az Apple token validálása
        // Jelenleg egyszerűsített változat - éles környezetben implementáld a teljes validálást
        console.log('✅ Apple token received (validation would happen here)');

        // Ellenőrizzük, hogy a user már létezik-e
        db.get(
            'SELECT * FROM users WHERE email = ? OR appleId = ?',
            [email, userIdentifier],
            async (err, existingUser) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({
                        message: 'Adatbázis hiba'
                    });
                }

                const userName = fullName ? `${fullName.givenName || ''} ${fullName.familyName || ''}`.trim() : 'Apple User';

                if (existingUser) {
                    // User már létezik - frissítsük az Apple adatokat
                    db.run(
                        'UPDATE users SET appleId = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?',
                        [userIdentifier, existingUser.id],
                        function(err) {
                            if (err) {
                                console.error('Update user error:', err);
                                return res.status(500).json({
                                    message: 'Hiba a felhasználó frissítésekor'
                                });
                            }

                            // Token generálás
                            const token = jwt.sign(
                                { id: existingUser.id },
                                JWT_SECRET,
                                { expiresIn: '30d' }
                            );

                            const userResponse = userToObject(existingUser);
                            
                            res.status(200).json({
                                token,
                                user: userResponse
                            });

                            console.log('✅ Apple login successful (existing user):', userResponse.email);
                        }
                    );
                } else {
                    // Új user létrehozása Apple adatokkal
                    const username = email ? email.split('@')[0] + '_apple' : 'apple_user_' + Date.now();
                    const userEmail = email || (userIdentifier + '@apple.com');
                    const age = 18; // Default age

                    const stmt = db.prepare(`
                        INSERT INTO users (
                            name, email, username, password, age,
                            appleId, isVerified,
                            location_city, location_country, skills, pricing, photos
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    `);

                    stmt.run(
                        userName,
                        userEmail,
                        username,
                        'apple_auth', // placeholder password
                        age,
                        userIdentifier,
                        1, // Apple users are automatically verified
                        '', // location_city
                        '', // location_country
                        '[]', // skills
                        '[]', // pricing
                        '[]', // photos
                        function(err) {
                            if (err) {
                                console.error('Insert error:', err);
                                return res.status(500).json({
                                    message: 'Hiba a felhasználó létrehozásakor'
                                });
                            }

                            // Új user lekérése
                            db.get(
                                'SELECT * FROM users WHERE id = ?',
                                [this.lastID],
                                (err, newUser) => {
                                    if (err) {
                                        console.error('Select error:', err);
                                        return res.status(500).json({
                                            message: 'Hiba a felhasználó lekérésekor'
                                        });
                                    }

                                    // Token generálás
                                    const token = jwt.sign(
                                        { id: newUser.id },
                                        JWT_SECRET,
                                        { expiresIn: '30d' }
                                    );

                                    const userResponse = userToObject(newUser);

                                    res.status(201).json({
                                        token,
                                        user: userResponse
                                    });

                                    console.log('✅ Apple registration successful:', userResponse.email);
                                }
                            );
                        }
                    );

                    stmt.finalize();
                }
            }
        );

    } catch (error) {
        console.error('Apple login error:', error);
        res.status(500).json({
            message: 'Hiba az Apple bejelentkezés során',
            error: error.message
        });
    }
});


app.post('/api/auth/google', async (req, res) => {
    try {
        const { token } = req.body;

        console.log('🔐 Google login request received');

        if (!token) {
            return res.status(400).json({
                message: 'Google token hiányzik'
            });
        }

        // Google token ellenőrzése
        const ticket = await googleClient.verifyIdToken({
            idToken: token,
            audience: GOOGLE_CLIENT_ID
        });

        const payload = ticket.getPayload();
        const { sub: googleId, email, name, picture } = payload;

        console.log('✅ Google token validated for:', email);

        // Ellenőrizzük, hogy a user már létezik-e
        db.get(
            'SELECT * FROM users WHERE email = ? OR googleId = ?',
            [email, googleId],
            async (err, existingUser) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({
                        message: 'Adatbázis hiba'
                    });
                }

                if (existingUser) {
                    // User már létezik - frissítsük a Google adatokat
                    db.run(
                        'UPDATE users SET googleId = ?, profileImageUrl = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?',
                        [googleId, picture, existingUser.id],
                        function(err) {
                            if (err) {
                                console.error('Update user error:', err);
                            }

                            // Token generálás
                            const token = jwt.sign(
                                { id: existingUser.id },
                                JWT_SECRET,
                                { expiresIn: '30d' }
                            );

                            const userResponse = userToObject(existingUser);
                            
                            res.status(200).json({
                                token,
                                user: userResponse
                            });

                            console.log('✅ Google login successful (existing user):', userResponse.email);
                        }
                    );
                } else {
                    // Új user létrehozása Google adatokkal
                    const username = email.split('@')[0] + '_google';
                    const age = 18; // Default age

                    const stmt = db.prepare(`
                        INSERT INTO users (
                            name, email, username, password, age,
                            googleId, profileImageUrl, isVerified,
                            location_city, location_country, skills, pricing, photos
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    `);

                    stmt.run(
                        name,
                        email,
                        username,
                        'google_auth', // placeholder password
                        age,
                        googleId,
                        picture,
                        1, // Google users are automatically verified
                        '', // location_city
                        '', // location_country
                        '[]', // skills
                        '[]', // pricing
                        '[]', // photos
                        function(err) {
                            if (err) {
                                console.error('Insert error:', err);
                                return res.status(500).json({
                                    message: 'Hiba a felhasználó létrehozásakor'
                                });
                            }

                            // Új user lekérése
                            db.get(
                                'SELECT * FROM users WHERE id = ?',
                                [this.lastID],
                                (err, newUser) => {
                                    if (err) {
                                        console.error('Select error:', err);
                                        return res.status(500).json({
                                            message: 'Hiba a felhasználó lekérésekor'
                                        });
                                    }

                                    // Token generálás
                                    const token = jwt.sign(
                                        { id: newUser.id },
                                        JWT_SECRET,
                                        { expiresIn: '30d' }
                                    );

                                    const userResponse = userToObject(newUser);

                                    res.status(201).json({
                                        token,
                                        user: userResponse
                                    });

                                    console.log('✅ Google registration successful:', userResponse.email);
                                }
                            );
                        }
                    );

                    stmt.finalize();
                }
            }
        );

    } catch (error) {
        console.error('Google login error:', error);
        res.status(500).json({
            message: 'Hiba a Google bejelentkezés során',
            error: error.message
        });
    }
});


// REGISZTRÁCIÓ
app.post('/api/auth/register', async (req, res) => {
    try {
        const { name, email, username, password, age } = req.body;

        console.log('Register request:', { name, email, username, age });

        // Validáció
        if (!name || !email || !username || !password || !age) {
            return res.status(400).json({
                message: 'Minden mező kitöltése kötelező.'
            });
        }

        if (password.length < 6) {
            return res.status(400).json({
                message: 'A jelszónak legalább 6 karakter hosszúnak kell lennie.'
            });
        }

        if (age < 16) {
            return res.status(400).json({
                message: 'A regisztrációhoz legalább 16 évesnek kell lenned.'
            });
        }

        // Ellenőrizzük, hogy létezik-e már ilyen email vagy username
        db.get(
            'SELECT * FROM users WHERE email = ? OR username = ?',
            [email, username],
            async (err, existingUser) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({
                        message: 'Adatbázis hiba'
                    });
                }

                if (existingUser) {
                    if (existingUser.email === email) {
                        return res.status(400).json({
                            message: 'Ez az email cím már regisztrálva van.'
                        });
                    }
                    if (existingUser.username === username) {
                        return res.status(400).json({
                            message: 'Ez a felhasználónév már foglalt.'
                        });
                    }
                }

                // Jelszó hash-elés
                const hashedPassword = await bcrypt.hash(password, 12);

                // Új user beszúrása
                const stmt = db.prepare(`
                    INSERT INTO users (
                        name, email, username, password, age,
                        location_city, location_country, skills, pricing, photos
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                `);

                stmt.run(
                    name,
                    email,
                    username,
                    hashedPassword,
                    age,
                    '', // location_city
                    '', // location_country
                    '[]', // skills
                    '[]', // pricing
                    '[]', // photos
                    function(err) {
                        if (err) {
                            console.error('Insert error:', err);
                            return res.status(500).json({
                                message: 'Hiba a felhasználó létrehozásakor'
                            });
                        }

                        // Új user lekérése
                        db.get(
                            'SELECT * FROM users WHERE id = ?',
                            [this.lastID],
                            (err, newUser) => {
                                if (err) {
                                    console.error('Select error:', err);
                                    return res.status(500).json({
                                        message: 'Hiba a felhasználó lekérésekor'
                                    });
                                }

                                // Token generálás
                                const token = jwt.sign(
                                    { id: newUser.id },
                                    JWT_SECRET,
                                    { expiresIn: '30d' }
                                );

                                const userResponse = userToObject(newUser);

                                res.status(201).json({
                                    token,
                                    user: userResponse
                                });

                                console.log('✅ Sikeres regisztráció:', userResponse.username);
                            }
                        );
                    }
                );

                stmt.finalize();
            }
        );

    } catch (error) {
        console.error('Register error:', error);
        res.status(500).json({
            message: 'Szerver hiba a regisztráció során.',
            error: error.message
        });
    }
});

// BEJELENTKEZÉS
app.post('/api/auth/login', async (req, res) => {
    try {
        const { identifier, password } = req.body;

        console.log('🔐 Login request received:', {
            identifier: identifier,
            passwordLength: password ? password.length : 0,
            timestamp: new Date().toISOString()
        });

        // Validáció
        if (!identifier || !password) {
            return res.status(400).json({
                message: 'Email/felhasználónév és jelszó megadása kötelező.'
            });
        }

        // User keresése email vagy username alapján
        db.get(
            'SELECT * FROM users WHERE email = ? OR username = ?',
            [identifier, identifier],
            async (err, user) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({
                        message: 'Adatbázis hiba'
                    });
                }

                if (!user) {
                    return res.status(401).json({
                        message: 'Hibás email/felhasználónév vagy jelszó.'
                    });
                }

                // Jelszó ellenőrzés
                const isPasswordValid = await bcrypt.compare(password, user.password);
                
                if (!isPasswordValid) {
                    return res.status(401).json({
                        message: 'Hibás email/felhasználónév vagy jelszó.'
                    });
                }

                // Token generálás
                const token = jwt.sign(
                    { id: user.id },
                    JWT_SECRET,
                    { expiresIn: '30d' }
                );

                const userResponse = userToObject(user);

                res.status(200).json({
                    token,
                    user: userResponse
                });

                console.log('✅ Sikeres bejelentkezés:', userResponse.username);
            }
        );

    } catch (error) {
        console.error('Login error:', error);
        res.status(500).json({
            message: 'Szerver hiba a bejelentkezés során.',
            error: error.message
        });
    }
});

// USER ADATOK LEKÉRÉSE (token alapján)
app.get('/api/auth/me', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({
                message: 'Hozzáférés megtagadva. Nincs token.'
            });
        }

        // Token ellenőrzés
        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({
                    message: 'Érvénytelen token.'
                });
            }

            // User keresése ID alapján
            db.get(
                'SELECT * FROM users WHERE id = ?',
                [decoded.id],
                (err, user) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({
                            message: 'Adatbázis hiba'
                        });
                    }

                    if (!user) {
                        return res.status(404).json({
                            message: 'Felhasználó nem található.'
                        });
                    }

                    const userResponse = userToObject(user);

                    res.status(200).json({
                        user: userResponse
                    });
                }
            );
        });

    } catch (error) {
        console.error('Get user error:', error);
        res.status(500).json({
            message: 'Szerver hiba az adatok lekérése során.'
        });
    }
});

// server.js - Verified státusz módosítása
// server.js - ADD THIS ROUTE

// USER ADATOK FRISSÍTÉSE
app.put('/api/auth/user/:userId', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        const { userId } = req.params;
        const updates = req.body;

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Csak a saját profilodat módosíthatod, kivéve ha admin vagy
            if (decoded.id !== userId) {
                db.get('SELECT userRole FROM users WHERE id = ?', [decoded.id], (err, adminUser) => {
                    if (err || adminUser.userRole !== 'admin') {
                        return res.status(403).json({ message: 'Nincs jogosultság' });
                    }

                    updateUser();
                });
            } else {
                updateUser();
            }
        });

        function updateUser() {
            const allowedFields = ['name', 'email', 'username', 'bio', 'age', 'location_city', 'location_country', 'phoneNumber'];
            const setClause = [];
            const values = [];

            Object.keys(updates).forEach(key => {
                if (allowedFields.includes(key)) {
                    if (key.startsWith('location_')) {
                        setClause.push(`${key} = ?`);
                        values.push(updates[key]);
                    } else {
                        setClause.push(`${key} = ?`);
                        values.push(updates[key]);
                    }
                }
            });

            if (setClause.length === 0) {
                return res.status(400).json({ message: 'Nincs érvényes frissítendő mező' });
            }

            setClause.push('updatedAt = CURRENT_TIMESTAMP');
            values.push(userId);

            const query = `UPDATE users SET ${setClause.join(', ')} WHERE id = ?`;

            db.run(query, values, function(err) {
                if (err) {
                    console.error('Update user error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                // Visszaadjuk a frissített usert
                db.get('SELECT * FROM users WHERE id = ?', [userId], (err, user) => {
                    if (err) {
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    const userResponse = userToObject(user);
                    res.status(200).json({
                        message: 'Profil sikeresen frissítve',
                        user: userResponse
                    });
                });
            });
        }

    } catch (error) {
        console.error('Update user error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});


// USER HITELESÍTÉSI STÁTUSZ MÓDOSÍTÁSA (Admin funkció)
app.put('/api/auth/verify-user/:userId', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        const { userId } = req.params;
        const { isVerified } = req.body;

        console.log('🔐 Verify user request:', { userId, isVerified });

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        // Token ellenőrzés
        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy admin-e
            db.get('SELECT userRole FROM users WHERE id = ?', [decoded.id], (err, adminUser) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!adminUser || adminUser.userRole !== 'admin') {
                    return res.status(403).json({ message: 'Csak admin módosíthatja a hitelesítési státuszt' });
                }

                // Frissítjük a user hitelesítési státuszát
                db.run(
                    'UPDATE users SET isVerified = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?',
                    [isVerified ? 1 : 0, userId],
                    function(err) {
                        if (err) {
                            console.error('Update verification error:', err);
                            return res.status(500).json({ message: 'Adatbázis hiba' });
                        }

                        if (this.changes === 0) {
                            return res.status(404).json({ message: 'Felhasználó nem található' });
                        }

                        console.log('✅ User verification updated:', { userId, isVerified });
                        
                        res.status(200).json({
                            message: `Felhasználó hitelesítési státusza ${isVerified ? 'aktiválva' : 'deaktiválva'}`,
                            userId: userId,
                            isVerified: isVerified
                        });
                    }
                );
            });
        });

    } catch (error) {
        console.error('Verify user error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

// USER HITELESÍTÉS FRISSÍTÉSE EMAIL ALAPJÁN
app.put('/api/auth/verify-by-email', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        const { email, isVerified } = req.body;

        console.log('🔐 Verify user by email:', { email, isVerified });

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Frissítjük a user hitelesítési státuszát email alapján
            db.run(
                'UPDATE users SET isVerified = ?, updatedAt = CURRENT_TIMESTAMP WHERE email = ?',
                [isVerified ? 1 : 0, email],
                function(err) {
                    if (err) {
                        console.error('Update verification error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    console.log('✅ Database changes:', this.changes);

                    if (this.changes === 0) {
                        return res.status(404).json({
                            message: 'Felhasználó nem található ezzel az email címmel',
                            email: email
                        });
                    }

                    console.log('✅ User verification updated by email:', { email, isVerified });
                    
                    res.status(200).json({
                        message: `Felhasználó hitelesítési státusza ${isVerified ? 'aktiválva' : 'deaktiválva'}`,
                        email: email,
                        isVerified: isVerified
                    });
                }
            );
        });

    } catch (error) {
        console.error('Verify user error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});
// HEALTH CHECK
app.get('/api/health', (req, res) => {
    res.json({
        status: 'OK',
        message: 'SkillTrade API működik',
        database: 'SQLite'
    });
});

// USER ADATOK MÓDOSÍTÁSA (Admin funkció)
app.put('/api/auth/users/:userId', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        const { userId } = req.params;
        const updates = req.body;

        console.log('🔧 User update request:', { userId, updates });

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy admin-e
            db.get('SELECT userRole FROM users WHERE id = ?', [decoded.id], (err, adminUser) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!adminUser || adminUser.userRole !== 'admin') {
                    return res.status(403).json({ message: 'Csak admin módosíthatja a felhasználói adatokat' });
                }

                updateUser();
            });

            function updateUser() {
                const allowedFields = ['name', 'email', 'username', 'age', 'userRole', 'status', 'isVerified'];
                const setClause = [];
                const values = [];

                Object.keys(updates).forEach(key => {
                    if (allowedFields.includes(key)) {
                        setClause.push(`${key} = ?`);
                        values.push(updates[key]);
                    }
                });

                if (setClause.length === 0) {
                    return res.status(400).json({ message: 'Nincs érvényes frissítendő mező' });
                }

                setClause.push('updatedAt = CURRENT_TIMESTAMP');
                values.push(userId);

                const query = `UPDATE users SET ${setClause.join(', ')} WHERE id = ?`;

                db.run(query, values, function(err) {
                    if (err) {
                        console.error('Update user error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    if (this.changes === 0) {
                        return res.status(404).json({ message: 'Felhasználó nem található' });
                    }

                    // Visszaadjuk a frissített usert
                    db.get('SELECT * FROM users WHERE id = ?', [userId], (err, user) => {
                        if (err) {
                            return res.status(500).json({ message: 'Adatbázis hiba' });
                        }

                        const userResponse = userToObject(user);
                        
                        console.log('✅ User updated successfully:', { userId, updates });
                        
                        res.status(200).json({
                            message: 'Felhasználó sikeresen frissítve',
                            user: userResponse
                        });
                    });
                });
            }
        });

    } catch (error) {
        console.error('Update user error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

// server.js - Javított útvonalak

// USER ADATOK MÓDOSÍTÁSA (UUID támogatással)
app.put('/api/auth/users/:userId', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        const { userId } = req.params;
        const updates = req.body;

        console.log('🔧 User update request:', { userId, updates });

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy admin-e
            db.get('SELECT userRole FROM users WHERE id = ?', [decoded.id], (err, adminUser) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!adminUser || adminUser.userRole !== 'admin') {
                    return res.status(403).json({ message: 'Csak admin módosíthatja a felhasználói adatokat' });
                }

                // UUID konvertálása integer ID-vá
                const userIdInt = convertUUIDtoInt(userId);
                if (!userIdInt) {
                    return res.status(400).json({ message: 'Érvénytelen felhasználó ID' });
                }

                updateUser(userIdInt);
            });

            function updateUser(userIdInt) {
                const allowedFields = ['name', 'email', 'username', 'age', 'userRole', 'status', 'isVerified'];
                const setClause = [];
                const values = [];

                Object.keys(updates).forEach(key => {
                    if (allowedFields.includes(key)) {
                        setClause.push(`${key} = ?`);
                        values.push(updates[key]);
                    }
                });

                if (setClause.length === 0) {
                    return res.status(400).json({ message: 'Nincs érvényes frissítendő mező' });
                }

                setClause.push('updatedAt = CURRENT_TIMESTAMP');
                values.push(userIdInt);

                const query = `UPDATE users SET ${setClause.join(', ')} WHERE id = ?`;

                db.run(query, values, function(err) {
                    if (err) {
                        console.error('Update user error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    if (this.changes === 0) {
                        return res.status(404).json({ message: 'Felhasználó nem található' });
                    }

                    // Visszaadjuk a frissített usert
                    db.get('SELECT * FROM users WHERE id = ?', [userIdInt], (err, user) => {
                        if (err) {
                            return res.status(500).json({ message: 'Adatbázis hiba' });
                        }

                        const userResponse = userToObject(user);
                        
                        console.log('✅ User updated successfully:', { userId: userIdInt, updates });
                        
                        res.status(200).json({
                            message: 'Felhasználó sikeresen frissítve',
                            user: userResponse
                        });
                    });
                });
            }
        });

    } catch (error) {
        console.error('Update user error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

// USER FELTÉTELEZÉSE (UUID támogatással)
app.put('/api/auth/users/:userId/suspend', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        const { userId } = req.params;
        const { suspended } = req.body;

        console.log('⏸️ Suspend user request:', { userId, suspended });

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy admin-e
            db.get('SELECT userRole FROM users WHERE id = ?', [decoded.id], (err, adminUser) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!adminUser || adminUser.userRole !== 'admin') {
                    return res.status(403).json({ message: 'Csak admin függeszthet fel/törölhet felhasználót' });
                }

                // UUID konvertálása integer ID-vá
                const userIdInt = convertUUIDtoInt(userId);
                if (!userIdInt) {
                    return res.status(400).json({ message: 'Érvénytelen felhasználó ID' });
                }

                const newStatus = suspended ? 'suspended' : 'active';

                db.run(
                    'UPDATE users SET status = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?',
                    [newStatus, userIdInt],
                    function(err) {
                        if (err) {
                            console.error('Suspend user error:', err);
                            return res.status(500).json({ message: 'Adatbázis hiba' });
                        }

                        if (this.changes === 0) {
                            return res.status(404).json({ message: 'Felhasználó nem található' });
                        }

                        console.log('✅ User suspension updated:', { userId: userIdInt, suspended });
                        
                        res.status(200).json({
                            message: `Felhasználó ${suspended ? 'felfüggesztve' : 'aktiválva'}`,
                            userId: userId,
                            suspended: suspended
                        });
                    }
                );
            });
        });

    } catch (error) {
        console.error('Suspend user error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

// server.js - DEBUG verzió
app.delete('/api/auth/users/:userId', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        const { userId } = req.params;

        console.log('🗑️ DELETE DEBUG - Received userId:', userId);
        console.log('🗑️ DELETE DEBUG - Type of userId:', typeof userId);
        console.log('🗑️ DELETE DEBUG - Full URL:', req.url);

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            console.log('🗑️ DELETE DEBUG - Decoded admin ID:', decoded.id);

            // Ellenőrizzük, hogy admin-e
            db.get('SELECT userRole FROM users WHERE id = ?', [decoded.id], (err, adminUser) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                console.log('🗑️ DELETE DEBUG - Admin user:', adminUser);

                if (!adminUser || adminUser.userRole !== 'admin') {
                    return res.status(403).json({ message: 'Csak admin törölhet felhasználót' });
                }

                // DIRECT APPROACH: Próbáljuk meg az userId-t direktben használni
                console.log('🗑️ DELETE DEBUG - Attempting to delete user with ID:', userId);
                
                // Először töröljük a kapcsolódó adatokat
                db.serialize(() => {
                    db.run('DELETE FROM works WHERE employerID = ?', [userId], function(err) {
                        if (err) console.error('Delete works error:', err);
                        else console.log(`🗑️ Deleted ${this.changes} works`);
                    });
                    
                    db.run('DELETE FROM work_applications WHERE applicantId = ? OR employerId = ?', [userId, userId], function(err) {
                        if (err) console.error('Delete applications error:', err);
                        else console.log(`🗑️ Deleted ${this.changes} applications`);
                    });
                    
                    // Végül töröljük a felhasználót
                    db.run('DELETE FROM users WHERE id = ?', [userId], function(err) {
                        if (err) {
                            console.error('❌ Delete user error:', err);
                            return res.status(500).json({ message: 'Adatbázis hiba' });
                        }

                        console.log('🗑️ DELETE RESULT - Database changes:', this.changes);

                        if (this.changes === 0) {
                            // Ha nem találta, próbáljuk meg integerré konvertálni
                            const userIdInt = parseInt(userId);
                            console.log('🗑️ TRYING INT CONVERSION:', userIdInt);
                            
                            if (!isNaN(userIdInt)) {
                                db.run('DELETE FROM users WHERE id = ?', [userIdInt], function(err) {
                                    if (err) {
                                        console.error('❌ Delete user error (int):', err);
                                        return res.status(500).json({ message: 'Adatbázis hiba' });
                                    }
                                    
                                    console.log('🗑️ DELETE RESULT (int) - Database changes:', this.changes);
                                    
                                    if (this.changes === 0) {
                                        return res.status(404).json({ message: 'Felhasználó nem található' });
                                    }
                                    
                                    res.status(200).json({
                                        message: 'Felhasználó sikeresen törölve',
                                        userId: userId
                                    });
                                });
                            } else {
                                return res.status(404).json({ message: 'Felhasználó nem található' });
                            }
                        } else {
                            res.status(200).json({
                                message: 'Felhasználó sikeresen törölve',
                                userId: userId
                            });
                        }
                    });
                });
            });
        });

    } catch (error) {
        console.error('Delete user error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});


// server.js - Email alapú törlés
app.delete('/api/auth/users/by-email/:email', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        const { email } = req.params;

        console.log('🗑️ EMAIL DELETE - Request received for email:', email);

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        // Token ellenőrzés
        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy admin-e
            db.get('SELECT userRole, email FROM users WHERE id = ?', [decoded.id], (err, adminUser) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!adminUser || adminUser.userRole !== 'admin') {
                    return res.status(403).json({ message: 'Csak admin törölhet felhasználót' });
                }

                // Nem lehet saját magadat törölni
                if (adminUser.email === email) {
                    return res.status(400).json({ message: 'Saját fiókodat nem törölheted' });
                }

                console.log('🗑️ EMAIL DELETE - Looking for user with email:', email);

                // Először keressük meg a user ID-t
                db.get('SELECT id FROM users WHERE email = ?', [email], (err, user) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    if (!user) {
                        console.log('❌ EMAIL DELETE - User not found with email:', email);
                        return res.status(404).json({
                            message: 'Felhasználó nem található ezzel az email címmel',
                            email: email
                        });
                    }

                    const userId = user.id;
                    console.log('✅ EMAIL DELETE - Found user ID:', userId, 'for email:', email);

                    // Töröljük a kapcsolódó adatokat
                    db.serialize(() => {
                        // Töröljük a munkákat
                        db.run('DELETE FROM works WHERE employerID = ?', [userId], function(err) {
                            if (err) {
                                console.error('Delete works error:', err);
                            } else {
                                console.log(`🗑️ Deleted ${this.changes} works`);
                            }
                        });
                        
                        // Töröljük a jelentkezéseket
                        db.run('DELETE FROM work_applications WHERE applicantId = ? OR employerId = ?', [userId, userId], function(err) {
                            if (err) {
                                console.error('Delete applications error:', err);
                            } else {
                                console.log(`🗑️ Deleted ${this.changes} applications`);
                            }
                        });
                        
                        // Végül töröljük a felhasználót
                        db.run('DELETE FROM users WHERE id = ?', [userId], function(err) {
                            if (err) {
                                console.error('Delete user error:', err);
                                return res.status(500).json({ message: 'Adatbázis hiba' });
                            }

                            console.log('✅ EMAIL DELETE - User deleted successfully, changes:', this.changes);
                            
                            res.status(200).json({
                                message: 'Felhasználó sikeresen törölve',
                                email: email,
                                userId: userId
                            });
                        });
                    });
                });
            });
        });

    } catch (error) {
        console.error('Email delete error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});


// Helper függvény UUID konvertálásához
function convertUUIDtoInt(uuid) {
    // Egyszerű hash-elés az UUID-ból integerré
    if (typeof uuid === 'number') {
        return uuid;
    }
    
    if (typeof uuid === 'string') {
        // Ha már integer string formátumban
        if (/^\d+$/.test(uuid)) {
            return parseInt(uuid);
        }
        
        // UUID hash-elése
        let hash = 0;
        for (let i = 0; i < uuid.length; i++) {
            const char = uuid.charCodeAt(i);
            hash = ((hash << 5) - hash) + char;
            hash = hash & hash; // Convert to 32bit integer
        }
        return Math.abs(hash);
    }
    
    return null;
}

// server.js - UUID mapping tábla
db.run(`CREATE TABLE IF NOT EXISTS uuid_mapping (
    uuid TEXT PRIMARY KEY,
    user_id INTEGER NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
)`);

// Helper függvény user ID lekéréséhez UUID alapján
function getUserIdFromUUID(uuid, callback) {
    if (typeof uuid === 'number') {
        return callback(uuid);
    }
    
    // Először próbáljuk meg a mapping táblából
    db.get('SELECT user_id FROM uuid_mapping WHERE uuid = ?', [uuid], (err, row) => {
        if (err || !row) {
            // Ha nincs mapping, hash-eljük
            const userId = convertUUIDtoInt(uuid);
            if (userId) {
                // Mentsük el a mappingot
                db.run('INSERT OR REPLACE INTO uuid_mapping (uuid, user_id) VALUES (?, ?)', [uuid, userId]);
                callback(userId);
            } else {
                callback(null);
            }
        } else {
            callback(row.user_id);
        }
    });
}

// JAVÍTOTT users endpoint - include isVerified field
app.get('/api/auth/users', (req, res) => {
    const token = req.headers.authorization?.split(' ')[1];
    
    if (!token) {
        return res.status(401).json({
            message: 'Hozzáférés megtagadva. Nincs token.'
        });
    }

    jwt.verify(token, JWT_SECRET, (err, decoded) => {
        if (err) {
            return res.status(401).json({
                message: 'Érvénytelen token.'
            });
        }

        // Ellenőrizzük, hogy admin-e a felhasználó
        db.get('SELECT userRole FROM users WHERE id = ?', [decoded.id], (err, user) => {
            if (err || !user || user.userRole !== 'admin') {
                return res.status(403).json({
                    message: 'Nincs jogosultság az admin panelhez.'
                });
            }

            // MÓDOSÍTOTT: include isVerified field
            db.all('SELECT id, name, email, username, age, isVerified, createdAt FROM users ORDER BY createdAt DESC', (err, rows) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({
                        message: 'Adatbázis hiba'
                    });
                }
                
                res.status(200).json({
                    users: rows,
                    count: rows.length
                });
            });
        });
    });
});

// server.js - JAVÍTOTT PROFILKÉP ENDPOINT
app.put('/api/auth/profile-image', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({
                message: 'Hozzáférés megtagadva. Nincs token.'
            });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({
                    message: 'Érvénytelen token.'
                });
            }

            const { profileImageData } = req.body;
            
            if (!profileImageData) {
                return res.status(400).json({
                    message: 'Hiányzó kép adatok.'
                });
            }

            console.log('📸 Profilkép frissítése user ID:', decoded.id);
            console.log('📏 Kép adat mérete:', profileImageData.length, 'karakter');
            
            // Képtömörítés - csak az első 100 karaktert logoljuk
            console.log('📸 Kép adat (első 100 karakter):', profileImageData.substring(0, 100) + '...');

            db.run(
                'UPDATE users SET profileImageData = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?',
                [profileImageData, decoded.id],
                function(err) {
                    if (err) {
                        console.error('❌ Profile image update error:', err);
                        return res.status(500).json({
                            message: 'Hiba a profilkép frissítésekor'
                        });
                    }

                    console.log('✅ Profilkép frissítve, changes:', this.changes);
                    
                    res.status(200).json({
                        message: 'Profilkép sikeresen frissítve',
                        userId: decoded.id
                    });
                }
            );
        });

    } catch (error) {
        console.error('❌ Profile image update error:', error);
        res.status(500).json({
            message: 'Szerver hiba a profilkép frissítése során.'
        });
    }
});

// PROFILKÉP LEKÉRÉSE
// server.js - Ellenőrizd, hogy ez a route megfelelően működik
app.get('/api/auth/profile-image/:userId', (req, res) => {
    try {
        const { userId } = req.params;

        db.get(
            'SELECT profileImageData FROM users WHERE id = ?',
            [userId],
            (err, row) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({
                        message: 'Adatbázis hiba'
                    });
                }

                if (!row) {
                    return res.status(404).json({
                        message: 'Felhasználó nem található.'
                    });
                }

                res.status(200).json({
                    profileImageData: row.profileImageData
                });
            }
        );

    } catch (error) {
        console.error('Profile image fetch error:', error);
        res.status(500).json({
            message: 'Szerver hiba a profilkép lekérése során.'
        });
    }
});

// server.js - Add these routes

// MUNKÁRA JELENTKEZÉS
app.post('/api/works/apply', (req, res) => {
    try {
        const {
            workId,
            applicantId,
            applicantName,
            serviceTitle,
            employerId,
            applicationDate
        } = req.body;

        console.log('\n📝 ÚJ JELENTKEZÉS:');
        console.log('  - Munka ID:', workId);
        console.log('  - Jelentkező ID:', applicantId);
        console.log('  - Jelentkező neve:', applicantName);
        console.log('  - Szolgáltatás:', serviceTitle);
        console.log('  - Munkáltató ID:', employerId);

        // Validáció
        if (!workId || !applicantId || !applicantName || !employerId) {
            return res.status(400).json({
                message: 'Hiányzó kötelező adatok.'
            });
        }

        // Ellenőrizzük, hogy létezik-e a munka
        db.get('SELECT id FROM works WHERE id = ?', [workId], (err, work) => {
            if (err) {
                console.error('❌ Adatbázis hiba:', err);
                return res.status(500).json({
                    message: 'Adatbázis hiba'
                });
            }

            if (!work) {
                return res.status(404).json({
                    message: 'Munka nem található.'
                });
            }

            // Ellenőrizzük, hogy a jelentkező már jelentkezett-e
            db.get(
                'SELECT id FROM work_applications WHERE workId = ? AND applicantId = ?',
                [workId, applicantId],
                (err, existingApplication) => {
                    if (err) {
                        console.error('❌ Adatbázis hiba:', err);
                        return res.status(500).json({
                            message: 'Adatbázis hiba'
                        });
                    }

                    if (existingApplication) {
                        return res.status(400).json({
                            message: 'Már jelentkeztél erre a munkára.'
                        });
                    }

                    // Új jelentkezés beszúrása
                    const applicationId = uuidv4();
                    const stmt = db.prepare(`
                        INSERT INTO work_applications (
                            id, workId, applicantId, applicantName, 
                            serviceTitle, employerId, applicationDate, status
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    `);

                    stmt.run(
                        applicationId,
                        workId,
                        applicantId,
                        applicantName,
                        serviceTitle,
                        employerId,
                        applicationDate || new Date().toISOString(),
                        'pending',
                        function(err) {
                            if (err) {
                                console.error('❌ Hiba a jelentkezés beszúrása során:', err);
                                return res.status(500).json({
                                    message: 'Hiba a jelentkezés során'
                                });
                            }

                            console.log('✅ JELENTKEZÉS SIKERESEN ROGZÍTVE!');
                            
                            res.status(200).json({
                                message: 'Sikeresen jelentkeztél a munkára!',
                                applicationId: applicationId
                            });
                        }
                    );

                    stmt.finalize();
                }
            );
        });

    } catch (error) {
        console.error('❌ Apply for work error:', error);
        res.status(500).json({
            message: 'Szerver hiba a jelentkezés során.',
            error: error.message
        });
    }
});

// JELENTKEZÉS ÁLLAPOTÁNAK LEKÉRÉSE
app.get('/api/works/:workId/applications/:applicantId', (req, res) => {
    try {
        const { workId, applicantId } = req.params;

        db.get(
            'SELECT * FROM work_applications WHERE workId = ? AND applicantId = ?',
            [workId, applicantId],
            (err, application) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({
                        message: 'Adatbázis hiba'
                    });
                }

                if (application) {
                    res.status(200).json({
                        hasApplied: true,
                        applicationDate: application.applicationDate,
                        status: application.status
                    });
                } else {
                    res.status(200).json({
                        hasApplied: false,
                        applicationDate: null
                    });
                }
            }
        );

    } catch (error) {
        console.error('Check application error:', error);
        res.status(500).json({
            message: 'Szerver hiba'
        });
    }
});

// MUNKA JELENTKEZÉSEINEK LEKÉRÉSE
app.get('/api/works/:workId/applications', (req, res) => {
    try {
        const { workId } = req.params;
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy a felhasználó a munkáltató-e
            db.get('SELECT employerID FROM works WHERE id = ?', [workId], (err, work) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!work) {
                    return res.status(404).json({ message: 'Munka nem található' });
                }

                // Csak a munkáltató érheti el a jelentkezéseket
                if (work.employerID !== decoded.id) {
                    return res.status(403).json({ message: 'Nincs jogosultság a jelentkezések megtekintéséhez' });
                }

                // Jelentkezések lekérése
                db.all(
                    `SELECT * FROM work_applications 
                     WHERE workId = ? 
                     ORDER BY applicationDate DESC`,
                    [workId],
                    (err, applications) => {
                        if (err) {
                            console.error('Database error:', err);
                            return res.status(500).json({ message: 'Adatbázis hiba' });
                        }

                        res.status(200).json({
                            applications: applications,
                            count: applications.length
                        });
                    }
                );
            });
        });

    } catch (error) {
        console.error('Get work applications error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

app.put('/api/works/applications/:applicationId/status', (req, res) => {
    try {
        const { applicationId } = req.params;
        const { status } = req.body;
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Először lekérjük a jelentkezést, hogy megtudjuk a munkát
            db.get(
                'SELECT wa.*, w.employerID FROM work_applications wa JOIN works w ON wa.workId = w.id WHERE wa.id = ?',
                [applicationId],
                (err, application) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    if (!application) {
                        return res.status(404).json({ message: 'Jelentkezés nem található' });
                    }

                    // Csak a munkáltató módosíthatja a státuszt
                    if (application.employerID !== decoded.id) {
                        return res.status(403).json({ message: 'Nincs jogosultság a jelentkezés módosításához' });
                    }

                    // Frissítjük a státuszt
                    db.run(
                        'UPDATE work_applications SET status = ? WHERE id = ?',
                        [status, applicationId],
                        function(err) {
                            if (err) {
                                console.error('Update application status error:', err);
                                return res.status(500).json({ message: 'Hiba a státusz frissítésekor' });
                            }

                            res.status(200).json({
                                message: 'Jelentkezés státusza sikeresen frissítve',
                                applicationId: applicationId,
                                status: status
                            });

                            console.log('✅ Jelentkezés státusz frissítve:', { applicationId, status });
                        }
                    );
                }
            );
        });

    } catch (error) {
        console.error('Update application status error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});


app.put('/api/works/:workId/employee', (req, res) => {
    try {
        const { workId } = req.params;
        const { employeeID, statusText } = req.body;
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy a felhasználó a munkáltató-e
            db.get('SELECT employerID FROM works WHERE id = ?', [workId], (err, work) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!work) {
                    return res.status(404).json({ message: 'Munka nem található' });
                }

                if (work.employerID !== decoded.id) {
                    return res.status(403).json({ message: 'Nincs jogosultság a munka módosításához' });
                }

                // Ellenőrizzük, hogy az employeeID létező user-e
                db.get('SELECT id FROM users WHERE id = ?', [employeeID], (err, user) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    if (!user) {
                        return res.status(404).json({ message: 'Munkavállaló nem található' });
                    }

                    // Frissítjük a munkát
                    db.run(
                        'UPDATE works SET employeeID = ?, statusText = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?',
                        [employeeID, statusText, workId],
                        function(err) {
                            if (err) {
                                console.error('Update work employee error:', err);
                                return res.status(500).json({ message: 'Hiba a munka frissítésekor' });
                            }

                            res.status(200).json({
                                message: 'Munka sikeresen frissítve',
                                workId: workId,
                                employeeID: employeeID,
                                statusText: statusText
                            });

                            console.log('✅ Munka frissítve:', { workId, employeeID, statusText });
                        }
                    );
                });
            });
        });

    } catch (error) {
        console.error('Update work employee error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});


app.delete('/api/works/:workId', (req, res) => {
    try {
        const { workId } = req.params;
        const { employerID } = req.body;
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy a felhasználó a munkáltató-e
            db.get('SELECT employerID FROM works WHERE id = ?', [workId], (err, work) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!work) {
                    return res.status(404).json({ message: 'Munka nem található' });
                }

                if (work.employerID !== employerID) {
                    return res.status(403).json({ message: 'Nincs jogosultság a munka törléséhez' });
                }

                // Először töröljük a kapcsolódó jelentkezéseket
                db.run('DELETE FROM work_applications WHERE workId = ?', [workId], (err) => {
                    if (err) {
                        console.error('Delete applications error:', err);
                        return res.status(500).json({ message: 'Hiba a jelentkezések törlésekor' });
                    }

                    // Majd töröljük a munkát
                    db.run('DELETE FROM works WHERE id = ?', [workId], function(err) {
                        if (err) {
                            console.error('Delete work error:', err);
                            return res.status(500).json({ message: 'Hiba a munka törlésekor' });
                        }

                        res.status(200).json({
                            message: 'Munka sikeresen törölve',
                            workId: workId
                        });

                        console.log('✅ Munka törölve:', workId);
                    });
                });
            });
        });

    } catch (error) {
        console.error('Delete work error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

// WORK_APPLICATIONS tábla létrehozása
db.run(`CREATE TABLE IF NOT EXISTS work_applications (
    id TEXT PRIMARY KEY,
    workId TEXT NOT NULL,
    applicantId TEXT NOT NULL,
    applicantName TEXT NOT NULL,
    serviceTitle TEXT NOT NULL,
    employerId TEXT NOT NULL,
    applicationDate DATETIME DEFAULT CURRENT_TIMESTAMP,
    status TEXT DEFAULT 'pending',
    FOREIGN KEY (workId) REFERENCES works(id),
    FOREIGN KEY (applicantId) REFERENCES users(id),
    FOREIGN KEY (employerId) REFERENCES users(id)
)`);

console.log('✅ Work applications tábla inicializálva');

// UUID generálás helper function
function uuidv4() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

// ÉRTÉKELÉSEK TÁBLA LÉTREHOZÁSA
db.run(`CREATE TABLE IF NOT EXISTS reviews (
    id TEXT PRIMARY KEY,
    reviewerId TEXT NOT NULL,
    reviewerName TEXT NOT NULL,
    reviewedUserId TEXT NOT NULL,
    workId TEXT NOT NULL,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    isReliable BOOLEAN DEFAULT 1,
    isPaid BOOLEAN DEFAULT 1,
    type TEXT NOT NULL CHECK (type IN ('employee', 'employer')),
    createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (reviewerId) REFERENCES users(id),
    FOREIGN KEY (reviewedUserId) REFERENCES users(id),
    FOREIGN KEY (workId) REFERENCES works(id)
)`);

console.log('✅ Reviews tábla inicializálva');

// ÚJ ÉRTÉKELÉS LÉTREHOZÁSA
app.post('/api/reviews', (req, res) => {
    try {
        const {
            reviewerId,
            reviewerName,
            reviewedUserId,
            workId,
            rating,
            comment,
            isReliable,
            isPaid,
            type
        } = req.body;

        console.log('\n⭐ ÚJ ÉRTÉKELÉS:');
        console.log('  - Értékelő:', reviewerName);
        console.log('  - Értékelt felhasználó:', reviewedUserId);
        console.log('  - Munka ID:', workId);
        console.log('  - Értékelés:', rating, 'csillag');
        console.log('  - Típus:', type);

        // Validáció
        if (!reviewerId || !reviewedUserId || !workId || !rating || !type) {
            return res.status(400).json({
                message: 'Hiányzó kötelező adatok.'
            });
        }

        if (rating < 1 || rating > 5) {
            return res.status(400).json({
                message: 'Az értékelés 1-5 csillag között lehet.'
            });
        }

        // Ellenőrizzük, hogy létezik-e a munka
        db.get('SELECT id FROM works WHERE id = ?', [workId], (err, work) => {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({
                    message: 'Adatbázis hiba'
                });
            }

            if (!work) {
                return res.status(404).json({
                    message: 'Munka nem található.'
                });
            }

            // Ellenőrizzük, hogy az értékelő már értékelt-e ezt a felhasználót ezen a munkán
            db.get(
                'SELECT id FROM reviews WHERE reviewerId = ? AND reviewedUserId = ? AND workId = ?',
                [reviewerId, reviewedUserId, workId],
                (err, existingReview) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({
                            message: 'Adatbázis hiba'
                        });
                    }

                    if (existingReview) {
                        return res.status(400).json({
                            message: 'Már értékelted ezt a felhasználót ennél a munkánál.'
                        });
                    }

                    // Új értékelés beszúrása
                    const reviewId = uuidv4();
                    const stmt = db.prepare(`
                        INSERT INTO reviews (
                            id, reviewerId, reviewerName, reviewedUserId, workId,
                            rating, comment, isReliable, isPaid, type
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    `);

                    stmt.run(
                        reviewId,
                        reviewerId,
                        reviewerName,
                        reviewedUserId,
                        workId,
                        rating,
                        comment || '',
                        isReliable !== undefined ? isReliable : 1,
                        isPaid !== undefined ? isPaid : 1,
                        type,
                        function(err) {
                            if (err) {
                                console.error('❌ Hiba az értékelés beszúrása során:', err);
                                return res.status(500).json({
                                    message: 'Hiba az értékelés létrehozásakor'
                                });
                            }

                            console.log('✅ ÉRTÉKELÉS SIKERESEN LÉTREHOZVA!');
                            
                            // Frissítjük a felhasználó átlagos értékelését
                            updateUserRating(reviewedUserId);
                            
                            res.status(201).json({
                                message: 'Értékelés sikeresen elküldve!',
                                reviewId: reviewId
                            });
                        }
                    );

                    stmt.finalize();
                }
            );
        });

    } catch (error) {
        console.error('❌ Create review error:', error);
        res.status(500).json({
            message: 'Szerver hiba az értékelés létrehozása során.',
            error: error.message
        });
    }
});

// FELHASZNÁLÓ ÉRTÉKELÉSEINEK LEKÉRÉSE
app.get('/api/reviews/user/:userId', (req, res) => {
    try {
        const { userId } = req.params;
        const { type } = req.query;

        let query = `
            SELECT r.*, w.title as workTitle
            FROM reviews r
            LEFT JOIN works w ON r.workId = w.id
            WHERE r.reviewedUserId = ?
        `;
        let params = [userId];

        if (type) {
            query += ' AND r.type = ?';
            params.push(type);
        }

        query += ' ORDER BY r.createdAt DESC';

        db.all(query, params, (err, rows) => {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({
                    message: 'Adatbázis hiba'
                });
            }

            const reviews = rows.map(row => ({
                id: row.id,
                reviewerId: row.reviewerId,
                reviewerName: row.reviewerName,
                reviewedUserId: row.reviewedUserId,
                workId: row.workId,
                workTitle: row.workTitle,
                rating: row.rating,
                comment: row.comment,
                isReliable: Boolean(row.isReliable),
                isPaid: Boolean(row.isPaid),
                type: row.type,
                createdAt: row.createdAt,
                updatedAt: row.updatedAt
            }));

            res.status(200).json({
                reviews: reviews,
                count: reviews.length
            });
        });

    } catch (error) {
        console.error('Get user reviews error:', error);
        res.status(500).json({
            message: 'Szerver hiba'
        });
    }
});

// MUNKA ÉRTÉKELÉSEINEK LEKÉRÉSE
app.get('/api/reviews/work/:workId', (req, res) => {
    try {
        const { workId } = req.params;

        db.all(
            `SELECT r.*, w.title as workTitle
             FROM reviews r
             LEFT JOIN works w ON r.workId = w.id
             WHERE r.workId = ?
             ORDER BY r.createdAt DESC`,
            [workId],
            (err, rows) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({
                        message: 'Adatbázis hiba'
                    });
                }

                const reviews = rows.map(row => ({
                    id: row.id,
                    reviewerId: row.reviewerId,
                    reviewerName: row.reviewerName,
                    reviewedUserId: row.reviewedUserId,
                    workId: row.workId,
                    workTitle: row.workTitle,
                    rating: row.rating,
                    comment: row.comment,
                    isReliable: Boolean(row.isReliable),
                    isPaid: Boolean(row.isPaid),
                    type: row.type,
                    createdAt: row.createdAt,
                    updatedAt: row.updatedAt
                }));

                res.status(200).json({
                    reviews: reviews,
                    count: reviews.length
                });
            }
        );

    } catch (error) {
        console.error('Get work reviews error:', error);
        res.status(500).json({
            message: 'Szerver hiba'
        });
    }
});

// SZEMÉLYES ÉRTÉKELÉSEK LEKÉRÉSE (amiket én írtam)
app.get('/api/reviews/my-reviews/:reviewerId', (req, res) => {
    try {
        const { reviewerId } = req.params;

        db.all(
            `SELECT r.*, w.title as workTitle, u.name as reviewedUserName
             FROM reviews r
             LEFT JOIN works w ON r.workId = w.id
             LEFT JOIN users u ON r.reviewedUserId = u.id
             WHERE r.reviewerId = ?
             ORDER BY r.createdAt DESC`,
            [reviewerId],
            (err, rows) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({
                        message: 'Adatbázis hiba'
                    });
                }

                const reviews = rows.map(row => ({
                    id: row.id,
                    reviewerId: row.reviewerId,
                    reviewerName: row.reviewerName,
                    reviewedUserId: row.reviewedUserId,
                    reviewedUserName: row.reviewedUserName,
                    workId: row.workId,
                    workTitle: row.workTitle,
                    rating: row.rating,
                    comment: row.comment,
                    isReliable: Boolean(row.isReliable),
                    isPaid: Boolean(row.isPaid),
                    type: row.type,
                    createdAt: row.createdAt,
                    updatedAt: row.updatedAt
                }));

                res.status(200).json({
                    reviews: reviews,
                    count: reviews.length
                });
            }
        );

    } catch (error) {
        console.error('Get my reviews error:', error);
        res.status(500).json({
            message: 'Szerver hiba'
        });
    }
});

// ÉRTÉKELÉS TÖRLÉSE
app.delete('/api/reviews/:reviewId', (req, res) => {
    try {
        const { reviewId } = req.params;
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy a felhasználó az értékelés szerzője-e
            db.get('SELECT reviewerId FROM reviews WHERE id = ?', [reviewId], (err, review) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!review) {
                    return res.status(404).json({ message: 'Értékelés nem található' });
                }

                if (review.reviewerId !== decoded.id) {
                    return res.status(403).json({ message: 'Csak a saját értékelésedet törölheted' });
                }

                db.run('DELETE FROM reviews WHERE id = ?', [reviewId], function(err) {
                    if (err) {
                        console.error('Delete review error:', err);
                        return res.status(500).json({ message: 'Hiba az értékelés törlésekor' });
                    }

                    res.status(200).json({
                        message: 'Értékelés sikeresen törölve',
                        reviewId: reviewId
                    });

                    console.log('✅ Értékelés törölve:', reviewId);
                });
            });
        });

    } catch (error) {
        console.error('Delete review error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

// FELHASZNÁLÓ ÁTLAGOS ÉRTÉKELÉSÉNEK FRISSÍTÉSE
function updateUserRating(userId) {
    db.all(
        'SELECT rating FROM reviews WHERE reviewedUserId = ?',
        [userId],
        (err, rows) => {
            if (err) {
                console.error('Error fetching reviews for rating update:', err);
                return;
            }

            if (rows.length === 0) {
                // Nincs értékelés, alapértelmezett érték
                db.run('UPDATE users SET rating = 0.0 WHERE id = ?', [userId]);
                return;
            }

            const totalRating = rows.reduce((sum, row) => sum + row.rating, 0);
            const averageRating = totalRating / rows.length;

            db.run(
                'UPDATE users SET rating = ? WHERE id = ?',
                [averageRating.toFixed(1), userId],
                (err) => {
                    if (err) {
                        console.error('Error updating user rating:', err);
                    } else {
                        console.log(`✅ User ${userId} rating updated to: ${averageRating.toFixed(1)}`);
                    }
                }
            );
        }
    );
}
// Works tábla létrehozása
db.run(`CREATE TABLE IF NOT EXISTS works (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    employerName TEXT NOT NULL,
    employerID TEXT NOT NULL,
    employeeID TEXT,
    wage REAL NOT NULL,
    paymentType TEXT NOT NULL,
    statusText TEXT DEFAULT 'Publikálva',
    startTime DATETIME,
    endTime DATETIME,
    duration INTEGER,
    progress REAL DEFAULT 0.0,
    location TEXT,
    skills TEXT DEFAULT '[]',
    category TEXT,
    description TEXT,
    createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    updatedAt DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (employerID) REFERENCES users(id)
)`);

console.log('✅ Works tábla inicializálva');

// WORK PUBLIKÁLÁS
app.post('/api/works/publish', (req, res) => {
    try {
        const {
            id, title, employerName, employerID, employeeID,
            wage, paymentType, statusText, startTime, endTime,
            duration, progress, location, skills, category, description
        } = req.body;

        console.log('\n🎯 ÚJ MUNKA ÉRKEZETT:');
        console.log('  - ID:', id);
        console.log('  - Cím:', title);
        console.log('  - Leírás:', description || 'Nincs leírás'); // DEBUG
        console.log('  - Munkáltató:', employerName);
        console.log('  - Munkáltató ID:', employerID);
        console.log('  - Bér:', wage, 'Ft');
        console.log('  - Fizetési mód:', paymentType);
        console.log('  - Hely:', location);
        console.log('  - Készségek:', skills);
        console.log('  - Leírás:', description);
        console.log('  - Státusz:', statusText);

        // Validáció
        if (!id || !title || !employerName || !employerID || !wage || !paymentType) {
            console.log('❌ Hiányzó adatok!');
            return res.status(400).json({
                message: 'Hiányzó kötelező adatok.'
            });
        }

        // Ellenőrizzük, hogy létezik-e a user - MÓDOSÍTOTT RÉSZ
        db.get('SELECT id FROM users WHERE id = ?', [employerID], (err, user) => {
            if (err) {
                console.error('❌ Adatbázis hiba:', err);
                return res.status(500).json({
                    message: 'Adatbázis hiba'
                });
            }

            if (!user) {
                console.log('⚠️  Figyelem: Felhasználó nem található ezzel az ID-vel:', employerID);
                console.log('📝 Ellenőrizzük, hogy létezik-e a felhasználó más formátumban...');
                
                // Alternatív keresés - UUID formátum ellenőrzése
                db.get('SELECT id FROM users', (err, allUsers) => {
                    if (err) {
                        console.error('❌ Hiba a felhasználók lekérésekor:', err);
                    } else {
                        console.log('📋 Elérhető felhasználók:', allUsers);
                    }
                });

                // INGYENES MEGOLDÁS: Elfogadjuk a munkát anélkül, hogy a user létezne
                // (Ez lehetővé teszi a tesztelést, de éles környezetben ezt meg kell oldani)
                console.log('✅ Munka elfogadva (fejlesztési mód)');
                insertWork();
                return;
            }

            // Ha a user létezik, beszúrjuk a munkát
            insertWork();
        });

        function insertWork() {
            // Munka beszúrása
            const stmt = db.prepare(`
                INSERT INTO works (
                    id, title, employerName, employerID, employeeID,
                    wage, paymentType, statusText, startTime, endTime,
                    duration, progress, location, skills, category, description
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            `);

            stmt.run(
                id,
                title,
                employerName,
                employerID, // Ezt most mindig elfogadjuk
                employeeID || null,
                wage,
                paymentType,
                statusText || 'Publikálva',
                startTime || null,
                endTime || null,
                duration || null,
                progress || 0.0,
                location || '',
                JSON.stringify(skills || []),
                category || '',
                description || '',
                function(err) {
                    if (err) {
                        console.error('❌ Hiba a munka beszúrása során:', err);
                        return res.status(500).json({
                            message: 'Hiba a munka publikálásakor'
                        });
                    }

                    console.log('✅ MUNKA SIKERESEN FELTÖLTVE!');
                    console.log('   - ID:', id);
                    console.log('   - Cím:', title);
                    console.log('   - Adatbázis ID:', this.lastID);

                    res.status(201).json({
                        message: 'Munka sikeresen publikálva',
                        workId: id
                    });
                }
            );

            stmt.finalize();
        }

    } catch (error) {
        console.error('❌ Publish work error:', error);
        res.status(500).json({
            message: 'Szerver hiba a munka publikálása során.',
            error: error.message
        });
    }
});

// MUNKÁK LEKÉRÉSE
// server.js - Javított /api/works endpoint

// MUNKÁK LEKÉRÉSE - JAVÍTOTT VERZIÓ
app.get('/api/works', (req, res) => {
    try {
        const { employerID, limit = 50 } = req.query;

        let query = `
            SELECT 
                w.id,
                w.title,
                COALESCE(u.name, w.employerName) as employerName,
                w.employerID,
                w.employeeID,
                w.wage,
                w.paymentType,
                w.statusText,
                w.startTime,
                w.endTime,
                w.duration,
                w.progress,
                w.location,
                w.skills,
                w.category,
                w.description,
                w.createdAt,
                w.updatedAt,
                u.profileImageUrl as employerProfileImage
            FROM works w
            LEFT JOIN users u ON w.employerID = u.id
            WHERE 1=1
        `;
        let params = [];

        if (employerID) {
            query += ' AND w.employerID = ?';
            params.push(employerID);
        }

        query += ' ORDER BY w.createdAt DESC LIMIT ?';
        params.push(parseInt(limit));

        console.log('📥 Works lekérdezés:', query);
        console.log('📥 Paraméterek:', params);

        db.all(query, params, (err, rows) => {
            if (err) {
                console.error('❌ Database error:', err);
                return res.status(500).json({
                    message: 'Adatbázis hiba'
                });
            }

            console.log(`📥 ${rows.length} munka lekérdezve`);

            // Részletes debug információk
            rows.forEach((row, index) => {
                console.log(`  Munka ${index + 1}:`);
                console.log(`    - ID: ${row.id}`);
                console.log(`    - Cím: ${row.title}`);
                console.log(`    - Munkáltató név: ${row.employerName}`);
                console.log(`    - Munkáltató ID: ${row.employerID}`);
                console.log(`    - Bér: ${row.wage}`);
                console.log(`    - Hely: ${row.location}`);
            });

            const works = rows.map(row => {
                // Biztosítjuk, hogy minden kötelező mező legyen értéke
                const work = {
                    id: row.id || '',
                    title: row.title || 'Névtelen munka',
                    employerName: row.employerName || 'Ismeretlen munkáltató',
                    employerID: row.employerID || '',
                    employeeID: row.employeeID || null,
                    wage: row.wage || 0,
                    paymentType: row.paymentType || 'Ismeretlen',
                    statusText: row.statusText || 'Publikálva',
                    startTime: row.startTime || null,
                    endTime: row.endTime || null,
                    duration: row.duration || null,
                    progress: row.progress || 0.0,
                    location: row.location || '',
                    skills: JSON.parse(row.skills || '[]'),
                    category: row.category || '',
                    description: row.description || '',
                    createdAt: row.createdAt || new Date().toISOString(),
                    updatedAt: row.updatedAt || new Date().toISOString(),
                    employerProfileImage: row.employerProfileImage || null
                };
                
                console.log(`  🔧 Feldolgozott munka: ${work.title} - ${work.employerName}`);
                return work;
            });

            res.status(200).json({
                works: works,
                count: works.length
            });
        });

    } catch (error) {
        console.error('❌ Get works error:', error);
        res.status(500).json({
            message: 'Szerver hiba a munkák lekérése során.'
        });
    }
});
// server.js - Add hozzá ezeket a végpontokat

// MUNKA LEKÉRÉSE ID ALAPJÁN
app.get('/api/works/:workId', (req, res) => {
    try {
        const { workId } = req.params;
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            db.get(
                `SELECT w.*, u.name as employerName, u.profileImageUrl as employerProfileImage
                 FROM works w
                 LEFT JOIN users u ON w.employerID = u.id
                 WHERE w.id = ?`,
                [workId],
                (err, row) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    if (!row) {
                        return res.status(404).json({ message: 'Munka nem található' });
                    }

                    const work = {
                        id: row.id,
                        title: row.title,
                        employerName: row.employerName,
                        employerID: row.employerID,
                        employeeID: row.employeeID,
                        wage: row.wage,
                        paymentType: row.paymentType,
                        statusText: row.statusText,
                        startTime: row.startTime,
                        endTime: row.endTime,
                        duration: row.duration,
                        progress: row.progress,
                        location: row.location,
                        skills: JSON.parse(row.skills || '[]'),
                        category: row.category,
                        description: row.description,
                        createdAt: row.createdAt,
                        updatedAt: row.updatedAt,
                        employerProfileImage: row.employerProfileImage
                    };

                    res.status(200).json({ work });
                }
            );
        });

    } catch (error) {
        console.error('Get work error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

// AKTÍV MUNKA LEKÉRÉSE DOLGOZÓ SZÁMÁRA
app.get('/api/works/employee/:employeeId/active', (req, res) => {
    try {
        const { employeeId } = req.params;
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Aktív munka keresése (Folyamatban státuszú)
            db.get(
                `SELECT w.*, u.name as employerName, u.profileImageUrl as employerProfileImage
                 FROM works w
                 LEFT JOIN users u ON w.employerID = u.id
                 WHERE w.employeeID = ? AND w.statusText = 'Folyamatban'`,
                [employeeId],
                (err, row) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    if (!row) {
                        return res.status(404).json({ message: 'Nincs aktív munka' });
                    }

                    const work = {
                        id: row.id,
                        title: row.title,
                        employerName: row.employerName,
                        employerID: row.employerID,
                        employeeID: row.employeeID,
                        wage: row.wage,
                        paymentType: row.paymentType,
                        statusText: row.statusText,
                        startTime: row.startTime,
                        endTime: row.endTime,
                        duration: row.duration,
                        progress: row.progress,
                        location: row.location,
                        skills: JSON.parse(row.skills || '[]'),
                        category: row.category,
                        description: row.description,
                        createdAt: row.createdAt,
                        updatedAt: row.updatedAt,
                        employerProfileImage: row.employerProfileImage
                    };

                    res.status(200).json({ work });
                }
            );
        });

    } catch (error) {
        console.error('Get active work error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

// MUNKA HOZZÁRENDELÉSE DOLGOZÓHOZ
app.put('/api/works/:workId/assign', (req, res) => {
    try {
        const { workId } = req.params;
        const { employeeID, statusText } = req.body;
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy a munka létezik-e
            db.get('SELECT * FROM works WHERE id = ?', [workId], (err, work) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!work) {
                    return res.status(404).json({ message: 'Munka nem található' });
                }

                // Ellenőrizzük, hogy a dolgozó létezik-e
                db.get('SELECT id FROM users WHERE id = ?', [employeeID], (err, employee) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    if (!employee) {
                        return res.status(404).json({ message: 'Dolgozó nem található' });
                    }

                    // Frissítjük a munkát
                    db.run(
                        'UPDATE works SET employeeID = ?, statusText = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?',
                        [employeeID, statusText, workId],
                        function(err) {
                            if (err) {
                                console.error('Assign employee error:', err);
                                return res.status(500).json({ message: 'Hiba a munka frissítésekor' });
                            }

                            res.status(200).json({
                                message: 'Dolgozó sikeresen hozzárendelve a munkához',
                                workId: workId,
                                employeeID: employeeID,
                                statusText: statusText
                            });

                            console.log('✅ Dolgozó hozzárendelve:', { workId, employeeID, statusText });
                        }
                    );
                });
            });
        });

    } catch (error) {
        console.error('Assign employee error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

app.put('/api/works/:workId/status', (req, res) => {
    try {
        const { workId } = req.params;
        const { statusText, employerID } = req.body;
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy a munka létezik-e
            db.get('SELECT * FROM works WHERE id = ?', [workId], (err, work) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!work) {
                    return res.status(404).json({ message: 'Munka nem található' });
                }

                // Ellenőrizzük, hogy a munkáltató létezik-e
                db.get('SELECT id FROM users WHERE id = ?', [employerID], (err, employer) => {
                    if (err) {
                        console.error('Database error:', err);
                        return res.status(500).json({ message: 'Adatbázis hiba' });
                    }

                    if (!employer) {
                        return res.status(404).json({ message: 'Munkáltató nem található' });
                    }

                    // Frissítjük a munka státuszát
                    db.run(
                        'UPDATE works SET statusText = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?',
                        [statusText, workId],
                        function(err) {
                            if (err) {
                                console.error('Update work status error:', err);
                                return res.status(500).json({ message: 'Hiba a munka frissítésekor' });
                            }

                            res.status(200).json({
                                message: 'Munka státusza sikeresen frissítve',
                                workId: workId,
                                statusText: statusText
                            });

                            console.log('✅ Munka státusz frissítve:', { workId, statusText });
                        }
                    );
                });
            });
        });

    } catch (error) {
        console.error('Update work status error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});


// MANUÁLIS KÓD ALAPJÁN MUNKA LEKÉRÉSE
app.get('/api/works/code/:manualCode', (req, res) => {
    try {
        const { manualCode } = req.params;
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Kód alapján munka keresése
            // A kód az első 8 karaktere a work ID-nek
            db.all('SELECT id FROM works', (err, allWorks) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                // Keresünk egy munkát, aminek az ID-jének első 8 karaktere megegyezik a kóddal
                const matchingWork = allWorks.find(work =>
                    work.id.substring(0, 8) === manualCode
                );

                if (!matchingWork) {
                    return res.status(404).json({ message: 'Nem található munka ezzel a kóddal' });
                }

                // Lekérjük a teljes munka adatokat
                db.get(
                    `SELECT w.*, u.name as employerName, u.profileImageUrl as employerProfileImage
                     FROM works w
                     LEFT JOIN users u ON w.employerID = u.id
                     WHERE w.id = ?`,
                    [matchingWork.id],
                    (err, row) => {
                        if (err) {
                            console.error('Database error:', err);
                            return res.status(500).json({ message: 'Adatbázis hiba' });
                        }

                        if (!row) {
                            return res.status(404).json({ message: 'Munka nem található' });
                        }

                        const work = {
                            id: row.id,
                            title: row.title,
                            employerName: row.employerName,
                            employerID: row.employerID,
                            employeeID: row.employeeID,
                            wage: row.wage,
                            paymentType: row.paymentType,
                            statusText: row.statusText,
                            startTime: row.startTime,
                            endTime: row.endTime,
                            duration: row.duration,
                            progress: row.progress,
                            location: row.location,
                            skills: JSON.parse(row.skills || '[]'),
                            category: row.category,
                            description: row.description,
                            createdAt: row.createdAt,
                            updatedAt: row.updatedAt,
                            employerProfileImage: row.employerProfileImage
                        };

                        res.status(200).json({ work });
                    }
                );
            });
        });

    } catch (error) {
        console.error('Get work by code error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});

// DEBUG: Token ellenőrző végpont
app.get('/api/auth/debug-token', (req, res) => {
    try {
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({
                message: 'Nincs token',
                hasToken: false
            });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({
                    message: 'Érvénytelen token',
                    isValid: false,
                    error: err.message
                });
            }

            res.status(200).json({
                message: 'Token érvényes',
                isValid: true,
                userId: decoded.id,
                expires: decoded.exp
            });
        });

    } catch (error) {
        console.error('Debug token error:', error);
        res.status(500).json({
            message: 'Szerver hiba',
            error: error.message
        });
    }
});
// MUNKA TÖRLÉSE
app.put('/api/works/:id', (req, res) => {
    try {
        const { id } = req.params;
        const updates = req.body;
        const token = req.headers.authorization?.split(' ')[1];

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy a felhasználó a munkáltató-e
            db.get('SELECT employerID FROM works WHERE id = ?', [id], (err, work) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!work) {
                    return res.status(404).json({ message: 'Munka nem található' });
                }

                if (work.employerID !== updates.employerID) {
                    return res.status(403).json({ message: 'Nincs jogosultság a munka frissítéséhez' });
                }

                // Megengedett mezők
                const allowedFields = ['title', 'wage', 'paymentType', 'statusText', 'location', 'skills', 'category', 'description'];
                const setClause = [];
                const values = [];

                Object.keys(updates).forEach(key => {
                    if (allowedFields.includes(key)) {
                        if (key === 'skills') {
                            setClause.push(`${key} = ?`);
                            values.push(JSON.stringify(updates[key]));
                        } else {
                            setClause.push(`${key} = ?`);
                            values.push(updates[key]);
                        }
                    }
                });

                if (setClause.length === 0) {
                    return res.status(400).json({ message: 'Nincs érvényes frissítendő mező' });
                }

                setClause.push('updatedAt = CURRENT_TIMESTAMP');
                values.push(id);

                const query = `UPDATE works SET ${setClause.join(', ')} WHERE id = ?`;

                db.run(query, values, function(err) {
                    if (err) {
                        console.error('Update work error:', err);
                        return res.status(500).json({ message: 'Hiba a munka frissítésekor' });
                    }

                    res.status(200).json({
                        message: 'Munka sikeresen frissítve',
                        workId: id
                    });

                    console.log('✅ Munka frissítve:', id);
                });
            });
        });

    } catch (error) {
        console.error('Update work error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});


app.get('/api/works/:id', (req, res) => {
    try {
        const { id } = req.params;

        db.get(
            `SELECT w.*, u.name as employerName, u.profileImageUrl as employerProfileImage
             FROM works w
             LEFT JOIN users u ON w.employerID = u.id
             WHERE w.id = ?`,
            [id],
            (err, row) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!row) {
                    return res.status(404).json({ message: 'Munka nem található' });
                }

                const work = {
                    id: row.id,
                    title: row.title,
                    employerName: row.employerName,
                    employerID: row.employerID,
                    employeeID: row.employeeID,
                    wage: row.wage,
                    paymentType: row.paymentType,
                    statusText: row.statusText,
                    startTime: row.startTime,
                    endTime: row.endTime,
                    duration: row.duration,
                    progress: row.progress,
                    location: row.location,
                    skills: JSON.parse(row.skills || '[]'),
                    category: row.category,
                    description: row.description,
                    createdAt: row.createdAt,
                    updatedAt: row.updatedAt,
                    employerProfileImage: row.employerProfileImage
                };

                res.status(200).json({ work });
            }
        );

    } catch (error) {
        console.error('Get work error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});


app.put('/api/works/:id/status', (req, res) => {
    try {
        const { id } = req.params;
        const { statusText, employerID } = req.body;
        const token = req.headers.authorization?.split(' ')[1];

        if (!token) {
            return res.status(401).json({ message: 'Hozzáférés megtagadva' });
        }

        jwt.verify(token, JWT_SECRET, (err, decoded) => {
            if (err) {
                return res.status(401).json({ message: 'Érvénytelen token' });
            }

            // Ellenőrizzük, hogy a felhasználó a munkáltató-e
            db.get('SELECT employerID FROM works WHERE id = ?', [id], (err, work) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'Adatbázis hiba' });
                }

                if (!work) {
                    return res.status(404).json({ message: 'Munka nem található' });
                }

                if (work.employerID !== employerID) {
                    return res.status(403).json({ message: 'Nincs jogosultság a státusz frissítéséhez' });
                }

                // Frissítjük a státuszt
                db.run(
                    'UPDATE works SET statusText = ?, updatedAt = CURRENT_TIMESTAMP WHERE id = ?',
                    [statusText, id],
                    function(err) {
                        if (err) {
                            console.error('Status update error:', err);
                            return res.status(500).json({ message: 'Hiba a státusz frissítésekor' });
                        }

                        res.status(200).json({
                            message: 'Munka státusza sikeresen frissítve',
                            workId: id,
                            statusText: statusText
                        });

                        console.log('✅ Munka státusz frissítve:', { id, statusText });
                    }
                );
            });
        });

    } catch (error) {
        console.error('Update work status error:', error);
        res.status(500).json({ message: 'Szerver hiba' });
    }
});



// Szerver indítása
const PORT = process.env.PORT || 3000;
const HOST = 'http://192.168.1.100:3000/api';
app.listen(PORT, () => {
    console.log(`🚀 SkillTrade szerver fut a http://localhost:${PORT} címen`);
    console.log(`📊 SQLite adatbázis: ${DB_PATH}`);
});
