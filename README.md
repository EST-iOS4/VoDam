# VoDam

당신의 목소리를 담아, 텍스트로 기록하다 ✨

"말로 하면 더 쉬운데, 타이핑은 귀찮을 때가 있잖아요"

회의, 강의, 인터뷰... 소중한 음성을 보담이 텍스트로 변환해드려요 🎙️

PDF 문서도 텍스트로 추출하고, 원하는 내용을 빠르게 검색해보세요 💫

<br/>

## 🎙️ 보담 주요 기능

🎤 **음성 녹음 & 실시간 STT**

- 녹음과 동시에 실시간으로 텍스트 변환! 말하는 순간 스크립트가 작성됩니다.

📁 **파일 기반 STT**

- 이미 녹음된 음성 파일도 텍스트로 변환할 수 있어요. 대용량 파일도 분할 처리로 안정적으로 변환됩니다.

📄 **PDF 텍스트 추출**

- PDF 문서를 업로드하면 OCR을 통해 텍스트를 추출하고 스크립트로 변환해드립니다.

🔍 **스크립트 검색 & 하이라이트**

- 변환된 스크립트에서 원하는 키워드를 검색하고, 하이라이트로 빠르게 찾아보세요.

💬 **AI 채팅**

- 스크립트 내용을 바탕으로 AI와 대화하며 요약, 질문, 분석을 받아보세요.

<br/>

## 🖥️ 개발 환경

- Xcode: **26+**
- Swift: **6**
- 배포타겟: **iOS 26+**
- 의존성 관리: **SPM**

<br/>

## 🌌 프로젝트 Overview

### 🔭 프로젝트 구조
- **TCA (The Composable Architecture)**

<br/>

### 🔑 핵심 기술 스택

- UI: **SwiftUI**
- Data: **SwiftData**

- Media: **AVFoundation**, **Speech**
    - STT(Speech-To-Text)를 구현하기 위해 Speech 프레임워크를 사용했습니다.
    - 실시간 STT와 파일 기반 STT 모두 지원하며, 대용량 파일은 분할 처리하여 안정적인 변환이 가능합니다.
    - 음성 녹음, 재생, 일시정지 등 오디오 제어를 위해 AVFoundation 프레임워크를 사용했습니다.

- PDF: **PDFKit**, **Vision**
    - PDF 문서에서 텍스트를 추출하기 위해 PDFKit을 활용했습니다.
    - 이미지 기반 PDF의 경우 Vision 프레임워크의 OCR 기능을 통해 텍스트를 인식합니다.

- Generative AI: **Gemini**
    - 스크립트 내용을 바탕으로 요약, 질문 응답 등의 기능을 제공하기 위해 Gemini API를 활용했습니다.

- Persistent: **SwiftData**
    - 녹음 파일과 스크립트 데이터를 로컬에 저장하고 관리하기 위해 SwiftData를 사용했습니다.

<br/>

## 팀원 소개

<table>
  <tr>
    <td align="center">
      <a href="https://github.com/algmza246">
        <img src="https://github.com/algmza246.png" width="100" height="100" style="border-radius: 50%;"><br>
        <b>강지원</b>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/Seo-garden">
        <img src="https://github.com/Seo-garden.png" width="100" height="100" style="border-radius: 50%;"><br>
        <b>서정원</b>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/iasdsr1347">
        <img src="https://github.com/iasdsr1347.png" width="100" height="100" style="border-radius: 50%;"><br>
        <b>송영민</b>
      </a>
    </td>
    <td align="center">
      <a href="https://github.com/dlrjswns">
        <img src="https://github.com/dlrjswns.png" width="100" height="100" style="border-radius: 50%;"><br>
        <b>이건준</b>
      </a>
    </td>
      <td align="center">
      <a href="https://github.com/EunYoungW">
        <img src="https://github.com/EunYoungW.png" width="100" height="100" style="border-radius: 50%;"><br>
        <b>왕은영</b>
      </a>
    </td>
  </tr>
  <tr>
    <td align="center">iOS Developer</td>
    <td align="center">iOS Developer</td>
    <td align="center">iOS Developer</td>
    <td align="center">iOS Developer</td>
    <td align="center">iOS Developer</td>
  </tr>
</table>

<br/>

