// 펫클 쇼핑 상품 가져오기 (개인 PC에서 실행)
//
// 준비
//   1) Firebase 콘솔 → 프로젝트 설정 → 서비스 계정 → "새 비공개 키 생성" → serviceAccount.json
//      (이 파일은 절대 깃에 올리지 말 것)
//   2) npm install firebase-admin
// 실행
//   node import_to_firestore.js ./serviceAccount.json          ← 미리보기(쓰기 없음)
//   node import_to_firestore.js ./serviceAccount.json --write  ← 실제 쓰기
//
// 쓰는 곳: sellers/aggaeng, products/nr-*, supplier_items/nr-*
// config/shop 은 건드리지 않는다 → 쇼핑 탭은 계속 "준비 중" 그대로.

const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const [, , keyPath, flag] = process.argv;
if (!keyPath) {
  console.error('사용법: node import_to_firestore.js <serviceAccount.json> [--write]');
  process.exit(1);
}
const WRITE = flag === '--write';

initializeApp({ credential: cert(require(path.resolve(keyPath))) });
const db = getFirestore();
const load = (f) => JSON.parse(fs.readFileSync(path.join(__dirname, 'out', f), 'utf8'));

async function put(collection, docs) {
  const now = FieldValue.serverTimestamp();
  let batch = db.batch();
  let n = 0;
  for (const { id, ...data } of docs) {
    const ref = db.collection(collection).doc(id);
    const exists = WRITE ? (await ref.get()).exists : false;
    const payload = { ...data, updatedAt: now, ...(exists ? {} : { createdAt: now }) };
    console.log(`${WRITE ? 'WRITE' : 'DRY  '} ${collection}/${id}  ${data.name || data.supplierName_raw || ''}`);
    if (WRITE) {
      batch.set(ref, payload, { merge: true });
      if (++n % 400 === 0) { await batch.commit(); batch = db.batch(); }
    }
  }
  if (WRITE) await batch.commit();
}

(async () => {
  await put('sellers', load('sellers.json'));
  await put('products', load('products.json'));
  await put('supplier_items', load('supplier_items.json'));
  console.log(WRITE ? '\n완료.' : '\n미리보기만 했습니다. 실제로 쓰려면 --write 를 붙이세요.');
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
