const fetch = require('node-fetch');

(async () => {
  try {
    const loginRes = await fetch('http://localhost:3000/api/auth/login', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({email: 'athlete1@test.com', password: 'Test1234!'})
    });
    const loginData = await loginRes.json();
    
    console.log('Login status:', loginRes.status);
    console.log('Token:', loginData.token?.slice(0, 20) + '...');
    
    const sessRes = await fetch('http://localhost:3000/api/sessions', {
      headers: {Authorization: `Bearer ${loginData.token}`}
    });
    const sesData = await sessRes.json();
    
    console.log('Sessions API status:', sessRes.status);
    console.log('Sessions count:', sesData.length);
    if (sesData.length > 0) {
      console.log('First session:', {id: sesData[0]._id, types: sesData[0].primaryTypes, date: sesData[0].date});
    }
  } catch (e) {
    console.error('Error:', e.message);
  }
  process.exit(0);
})();
