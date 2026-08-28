import { createClientFromRequest } from 'npm:@base44/sdk@0.8.31';

export default async function handler(req: any, res: any) {
  try {
    const base44 = createClientFromRequest(req);
    const { action, email, publicKey, signingKey } = req.body || req.query;

    if (action === 'publish') {
      // Store the user's public encryption keys on their KoraUser record
      // Private keys NEVER touch the server — only public keys are published
      const users = await base44.entities.KoraUser.filter({ email });
      if (!users || users.length === 0) {
        return res.status(404).json({ error: 'User not found' });
      }
      await base44.entities.KoraUser.update(users[0].id, {
        publicKey: publicKey || '',
        signingKey: signingKey || ''
      });
      return res.json({ success: true, message: 'Public keys published' });
    }

    if (action === 'lookup') {
      // Look up a user's public encryption keys by email or koraId
      const { lookupKey, lookupValue } = req.body || req.query;
      const filter: any = {};
      if (lookupKey === 'email') filter.email = lookupValue;
      else if (lookupKey === 'koraId') filter.koraId = lookupValue;
      else filter.email = email;
      const users = await base44.entities.KoraUser.filter(filter);
      if (!users || users.length === 0) {
        return res.status(404).json({ error: 'User not found' });
      }
      const user = users[0];
      return res.json({
        email: user.email,
        fullName: user.fullName,
        publicKey: user.publicKey || '',
        signingKey: user.signingKey || ''
      });
    }

    return res.status(400).json({ error: 'Invalid action. Use "publish" or "lookup".' });
  } catch (error: any) {
    console.error('[koraE2eeKeys] Error:', error);
    return res.status(500).json({ error: error.message || 'Internal error' });
  }
}
