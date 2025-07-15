using UnityEngine;
using System.Collections;
using DG.Tweening;



public class CameraTween : MonoBehaviour {

	public Vector3 randomTargetPos1;
	public Vector3 randomTargetPos2;
	public Vector3 randomTargetPos3;

	public float duration = 4; //时间



	// Use this for initialization
	IEnumerator Start () {

		Vector3 originPos = transform.position;
		yield return new WaitForSeconds(1);

		Sequence s = DOTween.Sequence();
		s.Append(transform.DOMove(randomTargetPos1, duration).SetRelative().SetEase(Ease.InOutQuad));
		s.Append(transform.DOMove(originPos, duration).SetEase(Ease.InOutQuad));

		s.Append(transform.DOMove(randomTargetPos2, duration).SetRelative().SetEase(Ease.InOutQuad));
		s.Append(transform.DOMove(originPos, duration).SetEase(Ease.InOutQuad));

		s.Append(transform.DOMove(randomTargetPos3, duration).SetRelative().SetEase(Ease.InOutQuad));
		s.Append(transform.DOMove(originPos, duration).SetEase(Ease.InOutQuad));
		s.SetLoops(-1);
	}
		
}
