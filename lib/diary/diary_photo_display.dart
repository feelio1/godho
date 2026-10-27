/// 상세 화면에서 사진을 넘길 때 미리 받아 둘(precache) 사진의 인덱스 —
/// 지금 보는 사진의 앞뒤([index]-1, [index]+1)만, 범위 밖은 뺀다("일기
/// 수정" 지시서 2-2). 상세에 처음 들어왔을 때([index]=0)는 이 공식
/// 그대로도 "첫 장·다음 장"이 된다(앞이 없으니 자연히 빠진다).
List<int> diaryPhotoPrecacheIndices({required int index, required int total}) {
  return [index - 1, index, index + 1].where((i) => i >= 0 && i < total).toList();
}
