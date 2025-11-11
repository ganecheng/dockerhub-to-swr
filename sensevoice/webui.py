# coding=utf-8

model = "iic/SenseVoiceSmall"
model = AutoModel(
    model="./models/"+model,
    trust_remote_code=False,
    device="cpu",
    disable_update=True,
)

demo.launch(server_name="0.0.0.0", server_port=7860)
