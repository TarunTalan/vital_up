# Backend Proxy Implementation for Food Scan Feature

This document describes the backend proxy implementation required for the FatSecret API integration in the VitalUp food scan feature. The proxy is necessary to keep API credentials secure and handle OAuth signing server-side.

## Overview

The Flutter app communicates with a backend proxy server instead of directly calling the FatSecret API. This proxy:
- Handles OAuth 1.0a signing for FatSecret API requests
- Keeps API keys and secrets secure (never exposed to client)
- Provides a simple REST API for the Flutter app
- Can optionally cache responses to reduce API calls

## Architecture

```
Flutter App → Backend Proxy → FatSecret API
                (OAuth 1.0a)
```

## Implementation Options

### Option 1: Firebase Cloud Functions (Recommended)

#### Setup

1. Install Firebase CLI:
```bash
npm install -g firebase-tools
firebase login
firebase init functions
```

2. Install dependencies:
```bash
cd functions
npm install crypto oauth-1.0a axios
```

#### Cloud Function Implementation

```javascript
// functions/index.js
const functions = require('firebase-functions');
const crypto = require('crypto');
const OAuth = require('oauth-1.0a');
const axios = require('axios');

// FatSecret API credentials (store in Firebase config)
const FATSECRET_API_KEY = functions.config().fatsecret.key;
const FATSECRET_API_SECRET = functions.config().fatsecret.secret;
const FATSECRET_API_URL = 'https://platform.fatsecret.com/rest/server.api';

const oauth = OAuth({
  consumer: { key: FATSECRET_API_KEY, secret: FATSECRET_API_SECRET },
  signature_method: 'HMAC-SHA1',
  hash_function: (baseString, key) => crypto.createHmac('sha1', key).update(baseString).digest('base64'),
});

// Food Image Recognition
exports.recognizeFood = functions.https.onRequest(async (req, res) => {
  // CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'GET, POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }

  try {
    const { imageData } = req.body;
    
    // Prepare FatSecret API request
    const requestData = {
      url: FATSECRET_API_URL,
      method: 'POST',
      data: {
        method: 'food.images.recognize',
        image_data: imageData,
        format: 'json',
      },
    };

    const request_data = {
      url: FATSECRET_API_URL,
      method: 'POST',
      data: requestData.data,
    };

    // Sign the request
    const signedData = oauth.toHeader(oauth.authorize(request_data));
    
    // Make the API call
    const response = await axios.post(FATSECRET_API_URL, requestData.data, {
      headers: {
        ...signedData,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    });

    res.json(response.data);
  } catch (error) {
    console.error('Error recognizing food:', error);
    res.status(500).json({ error: 'Failed to recognize food' });
  }
});

// Get Food Nutrition Info
exports.getNutrition = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'GET, POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }

  try {
    const { foodId } = req.body;
    
    const requestData = {
      url: FATSECRET_API_URL,
      method: 'POST',
      data: {
        method: 'food.get',
        food_id: foodId,
        format: 'json',
      },
    };

    const request_data = {
      url: FATSECRET_API_URL,
      method: 'POST',
      data: requestData.data,
    };

    const signedData = oauth.toHeader(oauth.authorize(request_data));
    
    const response = await axios.post(FATSECRET_API_URL, requestData.data, {
      headers: {
        ...signedData,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    });

    res.json(response.data);
  } catch (error) {
    console.error('Error getting nutrition:', error);
    res.status(500).json({ error: 'Failed to get nutrition info' });
  }
});

// Search Food by Name
exports.searchFood = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'GET, POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    res.status(204).send('');
    return;
  }

  try {
    const { query } = req.body;
    
    const requestData = {
      url: FATSECRET_API_URL,
      method: 'POST',
      data: {
        method: 'foods.search',
        search_expression: query,
        format: 'json',
      },
    };

    const request_data = {
      url: FATSECRET_API_URL,
      method: 'POST',
      data: requestData.data,
    };

    const signedData = oauth.toHeader(oauth.authorize(request_data));
    
    const response = await axios.post(FATSECRET_API_URL, requestData.data, {
      headers: {
        ...signedData,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    });

    res.json(response.data);
  } catch (error) {
    console.error('Error searching food:', error);
    res.status(500).json({ error: 'Failed to search food' });
  }
});
```

#### Deploy

```bash
# Set environment variables
firebase functions:config:set fatsecret.key="YOUR_API_KEY" fatsecret.secret="YOUR_API_SECRET"

# Deploy
firebase deploy --only functions
```

#### Update Flutter Repository URLs

Update the backend proxy URLs in the repository implementations:

```dart
// In food_recognition_repository_impl.dart
static const String _backendProxyUrl = 'https://YOUR_PROJECT.cloudfunctions.net/recognizeFood';

// In nutrition_repository_impl.dart
static const String _backendProxyUrl = 'https://YOUR_PROJECT.cloudfunctions.net/getNutrition';
static const String _searchProxyUrl = 'https://YOUR_PROJECT.cloudfunctions.net/searchFood';
```

### Option 2: Node.js/Express Server

#### Setup

```bash
mkdir backend-proxy
cd backend-proxy
npm init -y
npm install express cors body-parser crypto oauth-1.0a axios dotenv
```

#### Server Implementation

```javascript
// server.js
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const crypto = require('crypto');
const OAuth = require('oauth-1.0a');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(bodyParser.json());

const FATSECRET_API_KEY = process.env.FATSECRET_API_KEY;
const FATSECRET_API_SECRET = process.env.FATSECRET_API_SECRET;
const FATSECRET_API_URL = 'https://platform.fatsecret.com/rest/server.api';

const oauth = OAuth({
  consumer: { key: FATSECRET_API_KEY, secret: FATSECRET_API_SECRET },
  signature_method: 'HMAC-SHA1',
  hash_function: (baseString, key) => crypto.createHmac('sha1', key).update(baseString).digest('base64'),
});

// Food Image Recognition
app.post('/api/recognize-food', async (req, res) => {
  try {
    const { imageData } = req.body;
    
    const requestData = {
      url: FATSECRET_API_URL,
      method: 'POST',
      data: {
        method: 'food.images.recognize',
        image_data: imageData,
        format: 'json',
      },
    };

    const request_data = {
      url: FATSECRET_API_URL,
      method: 'POST',
      data: requestData.data,
    };

    const signedData = oauth.toHeader(oauth.authorize(request_data));
    
    const response = await axios.post(FATSECRET_API_URL, requestData.data, {
      headers: {
        ...signedData,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    });

    res.json(response.data);
  } catch (error) {
    console.error('Error recognizing food:', error);
    res.status(500).json({ error: 'Failed to recognize food' });
  }
});

// Get Food Nutrition Info
app.post('/api/nutrition', async (req, res) => {
  try {
    const { foodId } = req.body;
    
    const requestData = {
      url: FATSECRET_API_URL,
      method: 'POST',
      data: {
        method: 'food.get',
        food_id: foodId,
        format: 'json',
      },
    };

    const request_data = {
      url: FATSECRET_API_URL,
      method: 'POST',
      data: requestData.data,
    };

    const signedData = oauth.toHeader(oauth.authorize(request_data));
    
    const response = await axios.post(FATSECRET_API_URL, requestData.data, {
      headers: {
        ...signedData,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    });

    res.json(response.data);
  } catch (error) {
    console.error('Error getting nutrition:', error);
    res.status(500).json({ error: 'Failed to get nutrition info' });
  }
});

// Search Food by Name
app.post('/api/search-food', async (req, res) => {
  try {
    const { query } = req.body;
    
    const requestData = {
      url: FATSECRET_API_URL,
      method: 'POST',
      data: {
        method: 'foods.search',
        search_expression: query,
        format: 'json',
      },
    };

    const request_data = {
      url: FATSECRET_API_URL,
      method: 'POST',
      data: requestData.data,
    };

    const signedData = oauth.toHeader(oauth.authorize(request_data));
    
    const response = await axios.post(FATSECRET_API_URL, requestData.data, {
      headers: {
        ...signedData,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    });

    res.json(response.data);
  } catch (error) {
    console.error('Error searching food:', error);
    res.status(500).json({ error: 'Failed to search food' });
  }
});

app.listen(PORT, () => {
  console.log(`Backend proxy server running on port ${PORT}`);
});
```

#### Environment Variables

Create `.env` file:

```
FATSECRET_API_KEY=your_api_key_here
FATSECRET_API_SECRET=your_api_secret_here
PORT=3000
```

#### Deploy Options

**Heroku:**
```bash
heroku create your-app-name
heroku config:set FATSECRET_API_KEY=your_key FATSECRET_API_SECRET=your_secret
git push heroku main
```

**Vercel:**
```bash
npm install -g vercel
vercel
```

**AWS EC2/DigitalOcean:**
- Deploy as a Node.js service
- Use PM2 for process management
- Set up nginx as reverse proxy

#### Update Flutter Repository URLs

```dart
// In food_recognition_repository_impl.dart
static const String _backendProxyUrl = 'https://your-backend-url.com/api/recognize-food';

// In nutrition_repository_impl.dart
static const String _backendProxyUrl = 'https://your-backend-url.com/api/nutrition';
static const String _searchProxyUrl = 'https://your-backend-url.com/api/search-food';
```

## Open Food Facts Integration

The barcode lookup uses Open Food Facts API directly from the Flutter app, as it doesn't require authentication:

```dart
// Current implementation in nutrition_repository_impl.dart
static const String _openFoodFactsUrl = 'https://world.openfoodfacts.org/api/v0/product';
```

No backend proxy is needed for Open Food Facts.

## Security Considerations

1. **Never expose API keys** in client-side code
2. **Use HTTPS** for all API communications
3. **Implement rate limiting** on the backend proxy
4. **Add authentication** to your backend proxy if needed
5. **Validate input** before forwarding to FatSecret API
6. **Log errors** securely (don't log sensitive data)
7. **Use environment variables** for secrets
8. **Implement caching** to reduce API calls and costs

## Testing

### Test the Backend Proxy

```bash
# Test recognize-food endpoint
curl -X POST https://your-proxy-url.com/api/recognize-food \
  -H "Content-Type: application/json" \
  -d '{"imageData": "base64_encoded_image"}'

# Test nutrition endpoint
curl -X POST https://your-proxy-url.com/api/nutrition \
  -H "Content-Type: application/json" \
  -d '{"foodId": "12345"}'

# Test search endpoint
curl -X POST https://your-proxy-url.com/api/search-food \
  -H "Content-Type: application/json" \
  -d '{"query": "apple"}'
```

## Monitoring

Set up monitoring for your backend proxy:
- Track API call counts and costs
- Monitor error rates
- Set up alerts for failures
- Log response times

## Cost Management

FatSecret API has rate limits and potential costs:
- Implement caching to reduce duplicate calls
- Monitor usage to stay within free tier limits
- Consider implementing request queuing for high traffic

## Next Steps

1. Choose implementation option (Firebase Cloud Functions recommended)
2. Set up the backend server
3. Configure environment variables with FatSecret credentials
4. Deploy the backend
5. Update Flutter repository URLs with your backend endpoint
6. Test the full integration end-to-end
7. Set up monitoring and alerting
