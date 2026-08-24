// Camada WebAuthn/passkeys para o login biométrico no navegador.
//
// O Flutter Web (local_auth) não acessa o sensor de biometria; o WebAuthn é a
// API padrão para usar o autenticador de plataforma (Windows Hello / Touch ID /
// digital) no navegador. Aqui criamos/validamos uma *passkey* de plataforma.
//
// Modelo de segurança: assim como no app nativo, a biometria apenas DESBLOQUEIA
// a sessão já salva localmente — não há verificação de assertion no servidor.
// O challenge é local e a presença/verificação do usuário (userVerification:
// "required") é o que garante que a pessoa correta está no dispositivo.
(function () {
  'use strict';

  var KEY = 'vitta_passkey_id';

  function bytesToB64url(buf) {
    var bytes = new Uint8Array(buf);
    var bin = '';
    for (var i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
    return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }

  function b64urlToBytes(s) {
    s = s.replace(/-/g, '+').replace(/_/g, '/');
    var pad = s.length % 4 ? 4 - (s.length % 4) : 0;
    s += '='.repeat(pad);
    var bin = atob(s);
    var bytes = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return bytes;
  }

  function randomBytes(n) {
    var b = new Uint8Array(n);
    crypto.getRandomValues(b);
    return b;
  }

  // O autenticador de plataforma (com verificação de usuário) está disponível?
  async function isAvailable() {
    try {
      if (!window.PublicKeyCredential) return false;
      return await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
    } catch (e) {
      return false;
    }
  }

  // Já existe uma passkey registrada neste navegador?
  function isEnrolled() {
    try {
      return !!localStorage.getItem(KEY);
    } catch (e) {
      return false;
    }
  }

  // Cria a passkey de plataforma e guarda o id da credencial localmente.
  async function enroll(userName) {
    try {
      var cred = await navigator.credentials.create({
        publicKey: {
          challenge: randomBytes(32),
          rp: { name: 'Vitta', id: location.hostname },
          user: {
            id: randomBytes(16),
            name: userName || 'vitta-user',
            displayName: userName || 'Vitta',
          },
          pubKeyCredParams: [
            { type: 'public-key', alg: -7 },   // ES256
            { type: 'public-key', alg: -257 }, // RS256
          ],
          authenticatorSelection: {
            authenticatorAttachment: 'platform',
            userVerification: 'required',
            residentKey: 'preferred',
          },
          timeout: 60000,
          attestation: 'none',
        },
      });
      if (!cred) return false;
      localStorage.setItem(KEY, bytesToB64url(cred.rawId));
      return true;
    } catch (e) {
      console.error('[vittaBiometric] enroll falhou', e);
      return false;
    }
  }

  // Solicita a verificação biométrica usando a passkey salva.
  async function authenticate() {
    try {
      var id = localStorage.getItem(KEY);
      if (!id) return false;
      var assertion = await navigator.credentials.get({
        publicKey: {
          challenge: randomBytes(32),
          rpId: location.hostname,
          allowCredentials: [{ type: 'public-key', id: b64urlToBytes(id) }],
          userVerification: 'required',
          timeout: 60000,
        },
      });
      return !!assertion;
    } catch (e) {
      console.error('[vittaBiometric] authenticate falhou', e);
      return false;
    }
  }

  function clear() {
    try {
      localStorage.removeItem(KEY);
    } catch (e) {}
  }

  window.vittaBiometric = {
    isAvailable: isAvailable,
    isEnrolled: isEnrolled,
    enroll: enroll,
    authenticate: authenticate,
    clear: clear,
  };
})();
