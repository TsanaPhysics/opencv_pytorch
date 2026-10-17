import torch, torch.nn as nn, numpy as np, json, onnxruntime as ort, common as C
from PIL import Image
ck=torch.load('out/2026-10-16-durian-leaf-model/models/durian_disease_model.pth'); m=C.build('mobilenet_v3_small',4); m.load_state_dict(ck['model_state_dict']); m.eval()
class AppModel(nn.Module):
    # คืนค่า (ความน่าจะเป็น 4 คลาส, แผนที่ Grad-CAM 7x7 ของคลาสที่ทายได้) คำนวณ Grad-CAM แบบปิดรูป (ไม่ต้องใช้ backprop)
    def __init__(s,m):
        super().__init__(); s.f=m.features; s.l1=m.classifier[0]; s.l2=m.classifier[3]
    def forward(s,x):
        A=s.f(x)                                   # [1,576,7,7]
        p=A.mean((2,3))                            # [1,576]
        h=s.l1(p); a=h*torch.clamp(h+3,0,6)/6      # hardswish
        logit=s.l2(a); prob=torch.softmax(logit,1)
        t=torch.argmax(logit,1)
        onehot=torch.nn.functional.one_hot(t,logit.shape[1]).to(x.dtype)
        w2=onehot@s.l2.weight                      # [1,1024]
        dh=torch.where(h< -3, torch.zeros_like(h), torch.where(h>3, torch.ones_like(h), (2*h+3)/6))
        g=(dh*w2)@s.l1.weight                       # d score / d p  [1,576]
        cam=torch.relu((g[:,:,None,None]*A).sum(1)) # [1,7,7]
        mn=cam.amin((1,2),keepdim=True); mx=cam.amax((1,2),keepdim=True)
        cam=(cam-mn)/(mx-mn+1e-8)
        return prob,cam
am=AppModel(m).eval()
torch.onnx.export(am,torch.randn(1,3,224,224),'app_model.onnx',input_names=['image'],output_names=['probabilities','cam'],opset_version=17,dynamo=False)
# ตรวจกับ Grad-CAM แบบ backprop
s=json.load(open('res_mobilenet_v3_small_official.json')); sess=ort.InferenceSession('app_model.onnx')
import torch.nn.functional as F
maxd=0; agree=0; corr=[]
for pth,y in zip(s['test_paths'],s['y']):
    x=C.eval_tf(Image.open(pth).convert('RGB').resize((224,224),Image.BILINEAR)).unsqueeze(0)
    pr,cam=sess.run(None,{'image':x.numpy()})
    xx=x.clone().requires_grad_(True); acts={}
    def _fh(mod,i,o):
        acts['a']=o; o.register_hook(lambda g: acts.__setitem__('g',g))
    hdl=m.features[-1].register_forward_hook(_fh)
    out=m(xx); t=out.argmax(1).item(); m.zero_grad(); out[0,t].backward(); hdl.remove()
    w=acts['g'].mean((2,3),keepdim=True); ref=F.relu((w*acts['a']).sum(1))[0].detach().numpy(); ref=(ref-ref.min())/(ref.max()-ref.min()+1e-8)
    maxd=max(maxd,np.abs(ref-cam[0]).max()); agree+=pr.argmax()==y
    with torch.no_grad(): maxd=max(maxd,np.abs(torch.softmax(m(x),1).numpy()-pr).max())
print('max diff vs pytorch (prob & cam):',maxd,'acc',agree,'/',len(s['y']))
import os; print(os.path.getsize('app_model.onnx')/1e6,'MB')
