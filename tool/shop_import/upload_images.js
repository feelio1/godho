// 펫클 쇼핑 상품 이미지 올리기 (개인 PC에서 실행)
//
// 준비
//   - import_to_firestore.js 와 같은 serviceAccount.json, firebase-admin
//   - 이미지 폴더: <폴더>/<상품id>/1.jpg, 2.jpg ... (Claude가 정리해 둔 폴더)
// 실행
//   node upload_images.js ./serviceAccount.json <이미지폴더>          ← 미리보기(쓰기 없음)
//   node upload_images.js ./serviceAccount.json <이미지폴더> --write  ← 실제 업로드
//
// 하는 일
//   1) Storage product_images/<상품id>/<n>.jpg 로 업로드(다운로드 토큰 포함)
//   2) Firestore products/<상품id>.images 를 그 URL 목록으로 교체
// 다른 필드·config/shop 은 건드리지 않는다.

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');

const [, , keyPath, imagesDir, flag] = process.argv;
if (!keyPath || !imagesDir) {
  console.error('사용법: node upload_images.js <serviceAccount.json> <이미지폴더> [--write]');
  process.exit(1);
}
const WRITE = flag === '--write';
const sa = require(path.resolve(keyPath));
initializeApp({ credential: cert(sa) });
const db = getFirestore();

async function findBucket() {
  for (const name of [`${sa.project_id}.firebasestorage.app`, `${sa.project_id}.appspot.com`]) {
    const b = getStorage().bucket(name);
    try { const [ok] = await b.exists(); if (ok) return b; } catch (_) {}
  }
  throw new Error('Storage 버킷을 찾지 못했어요. Firebase 콘솔에서 Storage가 켜져 있는지 확인하세요.');
}

const urlOf = (bucket, objectPath, token) =>
  `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encodeURIComponent(objectPath)}?alt=media&token=${token}`;

(async () => {
  const bucket = await findBucket();
  console.log(`버킷: ${bucket.name}\n`);
  const ids = fs.readdirSync(imagesDir).filter((d) => fs.statSync(path.join(imagesDir, d)).isDirectory()).sort();
  let total = 0;
  for (const id of ids) {
    const ref = db.collection('products').doc(id);
    if (!(await ref.get()).exists) { console.log(`건너뜀 ${id} (products 문서 없음)`); continue; }
    const files = fs.readdirSync(path.join(imagesDir, id))
      .filter((f) => /^\d+\.jpg$/i.test(f))
      .sort((a, b) => parseInt(a) - parseInt(b));
    const urls = [];
    for (const f of files) {
      const objectPath = `product_images/${id}/${f}`;
      const token = crypto.randomUUID();
      if (WRITE) {
        await bucket.upload(path.join(imagesDir, id, f), {
          destination: objectPath,
          metadata: {
            contentType: 'image/jpeg',
            cacheControl: 'public, max-age=86400',
            metadata: { firebaseStorageDownloadTokens: token },
          },
        });
      }
      urls.push(urlOf(bucket.name, objectPath, token));
      total++;
    }
    console.log(`${WRITE ? 'UPLOAD' : 'DRY   '} ${id}  ${files.length}장`);
    if (WRITE) await ref.update({ images: urls, updatedAt: FieldValue.serverTimestamp() });
  }
  console.log(WRITE ? `\n완료: ${total}장` : `\n미리보기만 했습니다 (${total}장). 실제로 올리려면 --write 를 붙이세요.`);
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
