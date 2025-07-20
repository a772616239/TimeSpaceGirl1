// Copyright 2019 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using ETModel;
using Google.Play.Review;
using UnityEngine;
using UnityEngine.UI;
using Debug = UnityEngine.Debug;

namespace ETHotfix
{
    public class ReviewMgr : MonoBehaviour
    {
        private static PlayReviewInfo _playReviewInfo;
        private ReviewManager _reviewManager;
        public static ReviewMgr inst;

        public static ReviewMgr Inst
        {
            set => inst = value;
        }

        public bool EnableShow = true;

        private void Awake()
        {
            inst = this;
            _reviewManager = new ReviewManager();
            XDebug.Log.l("[ReviewMgr]Initialized key mapping");
            StartCoroutine(Wait());
        }

        IEnumerator Wait()
        {
            yield return new WaitForSeconds(2);
            AllInOneFlowClick();
        }
        public void AllInOneFlowClick()
        {
            if (!EnableShow)
            {
                XDebug.Log.l("[ReviewMgr]没有达到条件");
                return;
            }
            StartCoroutine(AllInOneFlowCoroutine());
        }

        private IEnumerator RequestFlowCoroutine(bool isStepRequest)
        {
            XDebug.Log.l("[ReviewMgr]Initializing in-app review request flow");
            var stopWatch = new Stopwatch();
            stopWatch.Start();
            if (_reviewManager==null)
            {
                _reviewManager = new ReviewManager();
            }
            var requestFlowOperation = _reviewManager.RequestReviewFlow();
            yield return requestFlowOperation;
            stopWatch.Stop();
            if (requestFlowOperation.Error != ReviewErrorCode.NoError)
            {
                ResetDisplay(requestFlowOperation.Error.ToString());
                yield break;
            }

            _playReviewInfo = requestFlowOperation.GetResult();
        }

        private IEnumerator LaunchFlowCoroutine()
        {
            // Gives enough time to the UI to progress to full dimmed (not interactable) LaunchFlowButton
            // before the in-app review dialog is shown.
            yield return new WaitForSeconds(.1f);
            if (_playReviewInfo == null)
            {
                ResetDisplay("[ReviewMgr]PlayReviewInfo is null.");
                yield break;
            }

            var launchFlowOperation = _reviewManager.LaunchReviewFlow(_playReviewInfo);
            yield return launchFlowOperation;
            _playReviewInfo = null;
            if (launchFlowOperation.Error != ReviewErrorCode.NoError)
            {
                ResetDisplay(launchFlowOperation.Error.ToString());
                yield break;
            }

            Debug.Log("[ReviewMgr]In-app review launch is done!"+launchFlowOperation.Error);
            ResetDisplay(string.Empty);
        }

        private IEnumerator AllInOneFlowCoroutine()
        {
            yield return StartCoroutine(RequestFlowCoroutine(false));
            yield return StartCoroutine(LaunchFlowCoroutine());
        }

        private void ResetDisplay(string errorText)
        {
            if (!string.IsNullOrEmpty(errorText))
            {
                Debug.LogError(errorText);
            }
        }
    }
}