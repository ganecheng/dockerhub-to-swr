
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import Optional
import os
import time

app = FastAPI(
    title="OpenAI-compatible TTS API",
    version="1.0"
)

# OpenAI 请求体模型（简化版，只取必要字段）
class SpeechRequest(BaseModel):
    model: str  # 虽然不用，但保留以兼容
    input: str  # 文本
    voice: str  # 映射为 speaker 音频文件名（如 "voice_01"）
    response_format: Optional[str] = "wav"  # 支持 wav/mp3，这里只支持 wav


@app.post("/v1/audio/speech")
async def create_speech(request: SpeechRequest):
    text = request.input.strip()
    if not text:
        raise HTTPException(status_code=400, detail="Input text is empty")

    # 将 voice 映射为音频文件路径
    spk_audio_path = f"examples/{request.voice}.wav"
    if not os.path.exists(spk_audio_path):
        raise HTTPException(status_code=400, detail=f"Speaker voice '{request.voice}' not found at {spk_audio_path}")

    timestamp_wav = f"spk_{int(time.time())}.wav"
    file_path = f"outputs/{timestamp_wav}"

    tts.infer(spk_audio_prompt=spk_audio_path, text=text, output_path=file_path, verbose=True)

    print(file_path)
    return FileResponse(file_path, media_type="audio/wav", filename=timestamp_wav)

def start_api():
    uvicorn.run(app, host=cmd_args.host, port=8000)

if __name__ == "__main__":
    t = threading.Thread(
        target=start_api,
        daemon=True,  # 主线程结束时，子线程一起退出
    )
    t.start()
    print("uvicorn.run fastapi started")
    demo.queue(20)
    demo.launch(server_name=cmd_args.host, server_port=cmd_args.port)
