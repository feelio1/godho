import 'book_input.dart';
import 'book_layout.dart';

/// 그림 칸 한 쪽에 넣는 최대 사진 수 — 옛 일기에 이보다 많아도 앞에서부터
/// 이만큼만 쓴다(일기 원본은 건드리지 않는다).
const int kBookMaxPhotosPerPage = 5;

/// 그림 칸 안 사진 사이 간격(mm).
const double kPhotoGapMm = 1.5;

/// 사진 수별 칸 배치 — 1장: 꽉 채움 / 2장: 좌우 / 3장: 왼쪽 큰 1 + 오른쪽
/// 위아래 2 / 4장: 2×2 / 5장: 왼쪽 큰 1 + 오른쪽 2×2.
List<MmRect> photoSlotRects(MmRect box, int count, {double gap = kPhotoGapMm}) {
  final x = box.x;
  final y = box.y;
  final w = box.width;
  final h = box.height;
  final halfW = (w - gap) / 2;
  final halfH = (h - gap) / 2;
  switch (count.clamp(0, kBookMaxPhotosPerPage)) {
    case 0:
      return const [];
    case 1:
      return [box];
    case 2:
      return [MmRect(x, y, halfW, h), MmRect(x + halfW + gap, y, halfW, h)];
    case 3:
      final bigW = (w - gap) * 0.6;
      final smallW = w - gap - bigW;
      return [
        MmRect(x, y, bigW, h),
        MmRect(x + bigW + gap, y, smallW, halfH),
        MmRect(x + bigW + gap, y + halfH + gap, smallW, halfH),
      ];
    case 4:
      return [
        MmRect(x, y, halfW, halfH),
        MmRect(x + halfW + gap, y, halfW, halfH),
        MmRect(x, y + halfH + gap, halfW, halfH),
        MmRect(x + halfW + gap, y + halfH + gap, halfW, halfH),
      ];
    default:
      final quarterW = (halfW - gap) / 2;
      final rightX = x + halfW + gap;
      return [
        MmRect(x, y, halfW, h),
        MmRect(rightX, y, quarterW, halfH),
        MmRect(rightX + quarterW + gap, y, quarterW, halfH),
        MmRect(rightX, y + halfH + gap, quarterW, halfH),
        MmRect(rightX + quarterW + gap, y + halfH + gap, quarterW, halfH),
      ];
  }
}

/// 칸 비율에 맞춰 가운데 기준으로 잘라낼 영역(cover). 사진 크기를 모르면
/// 자르지 않는다(렌더러가 칸에 맞춰 채운다).
CropRect coverCrop({required int photoWidthPx, required int photoHeightPx, required MmRect slot}) {
  if (photoWidthPx <= 0 || photoHeightPx <= 0 || slot.width <= 0 || slot.height <= 0) return CropRect.full;
  final photoAspect = photoWidthPx / photoHeightPx;
  final slotAspect = slot.width / slot.height;
  if (photoAspect > slotAspect) {
    final w = slotAspect / photoAspect;
    return CropRect((1 - w) / 2, 0, w, 1);
  }
  final h = photoAspect / slotAspect;
  return CropRect(0, (1 - h) / 2, 1, h);
}

/// 인쇄 해상도(dpi) = 칸에 실제로 쓰이는 사진 픽셀 ÷ (칸 mm / 25.4).
/// cover로 잘라내므로 가로·세로 어느 쪽으로 재도 같은 값이다.
double? photoDpi({required int photoWidthPx, required int photoHeightPx, required MmRect slot, required CropRect crop}) {
  if (photoWidthPx <= 0 || photoHeightPx <= 0 || slot.width <= 0) return null;
  return photoWidthPx * crop.width / (slot.width / 25.4);
}

PhotoSlot buildPhotoSlot(BookPhoto photo, MmRect rect, {required double minDpi}) {
  final crop = coverCrop(photoWidthPx: photo.widthPx, photoHeightPx: photo.heightPx, slot: rect);
  final dpi = photoDpi(photoWidthPx: photo.widthPx, photoHeightPx: photo.heightPx, slot: rect, crop: crop);
  return PhotoSlot(rect: rect, photo: photo, crop: crop, dpi: dpi, lowResolution: dpi != null && dpi < minDpi);
}
