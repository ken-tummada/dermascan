import os
import numpy as np
import matplotlib.pyplot as plt
from sklearn.metrics import roc_curve, auc
from sklearn.preprocessing import label_binarize
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from tensorflow.keras.models import load_model

plt.rcParams['font.family'] = 'DIN Alternate'

base_dir = r"D:\Project\Tumor"
val_dir = os.path.join(base_dir, "val")
model_path = os.path.join(base_dir, "ML_Model", "tumor_classifier.h5")
model = load_model(model_path)

img_size = (224, 224)
val_datagen = ImageDataGenerator(rescale=1./255)
val_generator = val_datagen.flow_from_directory(
    val_dir,
    target_size=img_size,
    batch_size=1,
    class_mode='categorical',
    shuffle=False
)

class_names = list(val_generator.class_indices.keys())
y_true = val_generator.classes
y_prob = model.predict(val_generator, verbose=1)
y_true_onehot = label_binarize(y_true, classes=list(range(len(class_names))))

plt.figure(figsize=(6,8.5))

colors = ['#019EA9', '#F56E03', '#F08DA9', '#7974E7', '#00C143', '#4D9CDD', '#D5A358', '#B1C700']

for i in range(len(class_names)):
    fpr, tpr, _ = roc_curve(y_true_onehot[:, i], y_prob[:, i])
    roc_auc = auc(fpr, tpr)
    plt.plot(fpr, tpr, lw=1.5, color=colors[i], label=f"{class_names[i]}  (AUC = {roc_auc:.2f})")  

plt.plot([0, 1], [0, 1], 'k--', lw=1, label='Random')

plt.xlim([0.0, 1.0])
plt.ylim([0.0, 1.02])
plt.xlabel('False Positive Rate / FPR', fontsize=18)
plt.ylabel('True Positive Rate / TPR', fontsize=18)
plt.title('ROC Curve - Multiclass', fontsize=22)
plt.xticks(fontsize=18)
plt.yticks(fontsize=18)

legend = plt.legend(loc='lower right', fontsize=16)
for legline in legend.get_lines():
    legline.set_linewidth(2.5)  

plt.grid(True, linestyle='--', linewidth=0.5, alpha=0.6)

plt.tight_layout()
plt.savefig(os.path.join(base_dir, "roc_curve.png"), dpi=300)
plt.show()
