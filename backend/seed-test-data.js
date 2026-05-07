/**
 * Seed test users and sample training data
 * Run from backend/: node seed-test-data.js
 */
require('dotenv').config();
const mongoose = require('mongoose');
const User = require('./models/User');
const TrainingSession = require('./models/TrainingSession');

const testUsers = [
  { name: 'ATS-2025-001', email: 'athlete1@test.com', password: 'Test1234!', sport: 'Cricket' },
  { name: 'ATS-2025-002', email: 'athlete2@test.com', password: 'Test1234!', sport: 'Cricket' },
];

// Sample session templates
const getSampleSessions = (athleteId, count = 10) => {
  const sessions = [];
  const now = new Date();
  const types = ['Running', 'Bowling', 'Gym', 'Yoga', 'Swimming', 'Cricket'];
  const skillTypes = ['Batting', 'Fielding', 'Bowling'];
  const sessionTypes = [
    'Match day',
    'Strength Program',
    'HIIT',
    'Endurance Program',
    'Core Program',
    'Corrective Prehab Program',
    'Rest day',
    'Power Program'
  ];

  for (let i = 0; i < count; i++) {
    const daysAgo = count - i;
    const date = new Date(now);
    date.setDate(date.getDate() - daysAgo);

    const primaryRpe = Math.floor(Math.random() * 6) + 5; // 5-10
    const primaryDuration = Math.floor(Math.random() * 90) + 30; // 30-120 min
    const primaryTypes = [types[Math.floor(Math.random() * types.length)]];
    const sessionType = sessionTypes[Math.floor(Math.random() * sessionTypes.length)];

    sessions.push({
      athlete: athleteId,
      date: date.toISOString(),
      sleep: Math.floor(Math.random() * 5) + 1, // 1-5 (1=best, 5=worst)
      wellness: Math.floor(Math.random() * 5) + 1, // 1-5 (1=best, 5=worst)
      soreness: Math.floor(Math.random() * 5) + 1, // 1-5
      fatigue: Math.floor(Math.random() * 5) + 1, // 1-5
      primaryTypes,
      primaryDuration,
      primaryRpe,
      sessionType,
      distance: Math.floor(Math.random() * 5000) + 500,
      sprints: Math.floor(Math.random() * 20),
      maxHR: Math.floor(Math.random() * 40) + 150,
      avgHR: Math.floor(Math.random() * 30) + 110,
      // Sometimes add secondary training
      ...(Math.random() > 0.6 ? {
        hasSecondary: true,
        secondaryTypes: [types[Math.floor(Math.random() * types.length)]],
        secondaryDuration: Math.floor(Math.random() * 45) + 15,
        secondaryRpe: Math.floor(Math.random() * 4) + 4,
      } : {}),
      // Sometimes add skill session
      ...(Math.random() > 0.5 ? {
        hasSkill: true,
        skillTypes: [skillTypes[Math.floor(Math.random() * skillTypes.length)]],
        skillDuration: Math.floor(Math.random() * 60) + 30,
        skillRpe: Math.floor(Math.random() * 6) + 5,
        ballsBowled: Math.floor(Math.random() * 24),
        skillMaxHR: Math.floor(Math.random() * 40) + 150,
        skillAvgHR: Math.floor(Math.random() * 30) + 110,
        // Sometimes add subordinate skill
        ...(Math.random() > 0.7 && {
          skillSubTypes: [skillTypes[Math.floor(Math.random() * skillTypes.length)]],
          skillSubDuration: Math.floor(Math.random() * 30) + 15,
          skillSubRpe: Math.floor(Math.random() * 5) + 3,
        }),
      } : {}),
    });
  }

  return sessions;
};

async function seed() {
  try {
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/fitness-app');
    console.log('✓ Connected to MongoDB');

    // Create users
    const createdUsers = [];
    for (const userData of testUsers) {
      let user = await User.findOne({ email: userData.email });
      if (!user) {
        user = await User.create(userData);
        console.log(`✓ Created user: ${user.email}`);
      } else {
        console.log(`• User already exists: ${user.email}`);
      }
      createdUsers.push(user);
    }

    // Create sessions for each user
    for (const user of createdUsers) {
      // Clear existing sessions for this user
      const deletedCount = await TrainingSession.deleteMany({ athlete: user._id });
      console.log(`  Cleared ${deletedCount.deletedCount} old sessions for ${user.email}`);

      // Create new sessions
      const sessions = getSampleSessions(user._id, 14);
      const inserted = await Promise.all(
        sessions.map(s => TrainingSession.create(s))
      );
      console.log(`  ✓ Created ${inserted.length} sample sessions for ${user.email}`);
    }

    console.log('\n✓ Seed complete!');
    console.log('\nTest credentials:');
    testUsers.forEach(u => {
      console.log(`  • ${u.email} / Test1234!`);
    });

    process.exit(0);
  } catch (err) {
    console.error('✗ Seed failed:', err.message);
    process.exit(1);
  }
}

seed();
