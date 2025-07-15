using UnityEngine;
using UnityEngine.UI;
using UnityEngine.EventSystems;
using System.Collections;
using System.Collections.Generic;
using System;
using GameLogic;
/// <summary>
/// UGUI ScrollRect 滑动元素居中
/// </summary>
public class UUICenterOnChild : MonoBehaviour, IBeginDragHandler, IEndDragHandler
{
    public float scrollSpeed = 8f;
    public Transform uUIGrid;
    private ScrollRect scrollRect;
    private float[] pageArray;
    private float targetPagePosition = 0f;
    private bool isDrag = false;
    private int pageCount;
    private int currentPage = 0;
    private List<Transform> items = new List<Transform>();
    Sprite dian_01;
    Sprite dian_02;
    GameObject ScrollView_Tip_Grid;
    float Timer = 5f;
    // Use this for initialization
    void Awake()
    {
        scrollRect = GetComponent<ScrollRect>();
        InitPageArray();
        dian_01 = App.ResMgr.LoadAsset<Sprite> ("Dian_01");
        dian_02 = App.ResMgr.LoadAsset<Sprite>("Dian_02");
        ScrollView_Tip_Grid = transform.parent.Find("ScrollView_Tip/Grid").gameObject;
    }
    void OnEnable()
    {
        InitPageArray();
    }
    void Start()
    {

    }
    void InitPageArray()
    {
        var activeCount = 0;
        foreach (Transform item in uUIGrid)
        {
            if (item.gameObject.active)
            { 
                items.Add(item);
                activeCount++;
            }
        }
        pageCount = activeCount;
        pageArray = new float[pageCount];
        for (int i = 0; i < pageCount; i++)
        {
            pageArray[i] = (1f / (pageCount - 1)) * i;
        }
    }

    // Update is called once per frame
    void Update()
    {
        if (!isDrag)
        {
            scrollRect.horizontalNormalizedPosition = Mathf.Lerp(scrollRect.horizontalNormalizedPosition, targetPagePosition, scrollSpeed * Time.deltaTime);
        }
        ChangePageByTime();
    }
    void ChangePageByTime()
    {
        Timer = Timer - Time.deltaTime;
        if (Timer <= 0f)
        {
            Timer = 5f;
            ToMove();
        
        }
    
    }

    public void OnBeginDrag(PointerEventData eventData)
    {
        isDrag = true;
    }

    public void OnEndDrag(PointerEventData eventData)
    {
        isDrag = false;
        float posX = scrollRect.horizontalNormalizedPosition;
        int index = 0;
        if (pageArray.Length > index)
        {
            float offset = Math.Abs(pageArray[index] - posX);
            for (int i = 1; i < pageArray.Length; i++)
            {
                float _offset = Math.Abs(pageArray[i] - posX);
                if (_offset < offset)
                {
                    index = i;
                    offset = _offset;
                }
            }
            targetPagePosition = pageArray[index];
            currentPage = index;
        }
     //   print(currentPage);
     //   print(ScrollView_Tip_Grid.transform.GetChild(currentPage).gameObject.name);
        ShowChangePage(currentPage);
    }
    //想左移动一个元素
    public void ToLeft()
    {
        if (currentPage > 0)
        {
            currentPage = currentPage - 1;
            targetPagePosition = pageArray[currentPage];
        }
    }
    //void OnGUI()
    //{
    //    if (GUI.Button(new Rect(10, 10, 150, 100), "ToLeft"))
    //        ToLeft();
    //    if (GUI.Button(new Rect(160, 10, 150, 100), "ToRight"))
    //        ToMove();

    //}
    //想右移动一个元素
    public void ToRight()
    {
        if (currentPage < pageCount - 1)
        {
            currentPage = currentPage + 1;
            targetPagePosition = pageArray[currentPage];
        }
    }
    bool AbleToRight = true;

    public void ToMove()
    {
        if (currentPage < pageCount - 1 && AbleToRight==true)//右移
        {
            currentPage = currentPage + 1;
            targetPagePosition = pageArray[currentPage];
        }
        else
        {
            AbleToRight = false;
            if (currentPage > 0)//左移
            {
                currentPage = currentPage - 1;
                targetPagePosition = pageArray[currentPage];
            }
            else
            {
                AbleToRight = true;
            }
        
        }
      //  print(currentPage);
      //  print(ScrollView_Tip_Grid.transform.GetChild(currentPage).gameObject.name);
        ShowChangePage(currentPage);
   
    }
    void ShowChangePage(int page)
    {
        if (ScrollView_Tip_Grid.transform.childCount > (page + 1))
        {
            ScrollView_Tip_Grid.transform.GetChild(page + 1).GetComponent<Image>().sprite = dian_02;
        }
        int childCount = ScrollView_Tip_Grid.transform.childCount;
        for (int i = 0; i < childCount; i++)
        {
            if (currentPage + 1 != i)
            {
                ScrollView_Tip_Grid.transform.GetChild(i).GetComponent<Image>().sprite = dian_01;
            }
        }
    
    
    }
    public int GetCurrentPageIndex()
    {
        return currentPage;
    }
    public void SetCurrentPageIndex(int index)
    {
        currentPage = index;
        targetPagePosition = pageArray[currentPage];
    }
    public int GetTotalPages()
    {
        return pageCount;
    }
}