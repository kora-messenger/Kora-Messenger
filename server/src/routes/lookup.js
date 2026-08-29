import { Router } from 'express';
import KoraUser from '../models/KoraUser.js';

const router = Router();

router.post('/', async (req, res) => {
  const { action } = req.body;

  try {
    if (action === 'lookupUser') {
      const { query } = req.body;
      if (!query) {
        return res.status(400).json({ error: 'Query is required' });
      }
      const user = await KoraUser.findOne({
        $or: [
          { email: query.toLowerCase() },
          { koraId: query },
          { username: query.toLowerCase() },
        ],
      }).select('email fullName koraId username avatarUrl bio isVerified isPremium');

      if (!user) {
        return res.json({ found: false });
      }
      return res.json({ found: true, user });
    }

    return res.status(400).json({ error: `Unknown action: ${action}` });
  } catch (err) {
    console.error('Lookup route error:', err);
    return res.status(500).json({ error: 'Internal server error', detail: err.message });
  }
});

export default router;
