Create DATA_QUALITY_LOG.md
# Data Quality & Cleaning Log

## 1. Tổng quan (Overview)
- **Bảng gốc (`raw_housing`):** [30229] dòng.
- **Bảng Staging (`stage_housing`):** [27527] dòng sau khi làm sạch.
- **Tỷ lệ giữ lại:** [91]%.

## 2. Các vấn đề dữ liệu phát hiện & Hướng xử lý (Data Issues & Solutions)

### Vấn đề 1: Lỗi định dạng địa chỉ gộp
- **Tình trạng:** Cột địa chỉ gốc chứa chuỗi dài không đồng nhất.
- **Giải pháp:** Dùng hàm mảng (SPLIT_PART, string_to_array) trong PostgreSQL để bóc tách thành `city` và `district`. Chuẩn hóa các tiền tố (bỏ "Thành phố", "Tỉnh").

### Vấn đề 2: Dữ liệu trống (Missing Values) ở các cột phân loại và các cột số   
- **Tình trạng:** Rất nhiều tin đăng bỏ trống thông tin quan trọng như Pháp lý (`legal_status`), Nội thất (`furniture_state`), Hướng nhà (`house_direction`) và các cột kích thước (`frontage_m`, '`floors`,....).
- **Giải pháp:** 
  - Dùng `COALESCE` gán giá trị 'Unknown' cho cột `legal_status` và `furniture_state`.
  - Giữ nguyên giá trị `NULL` cho các cột kiểu số và `house_direction`,`balcony_direction`.
- **Lý do (Tư duy phân tích):** 
  - **Tại sao không xóa dòng:** Việc thiếu thông tin pháp lý không làm mất đi giá trị cốt lõi của tin đăng là Giá và Diện tích. Nếu xóa thẳng tay, ta sẽ mất đi một lượng lớn mẫu dữ liệu quan trọng để tính toán mặt bằng giá chung của thị trường.
  - **Tại sao gom thành 'Unknown': ? ** Trong bất động sản, việc "giấu" thông tin pháp lý hay nội thất cũng là một tín hiệu (signal) đáng chú ý. Phân loại chúng vào nhóm 'Unknown' giúp trả lời được câu hỏi kinh doanh: *"Những căn nhà mập mờ pháp lý có giá rẻ hơn bao nhiêu % so với nhà có sổ đỏ?"*.
  - **Tại sao không áp dụng cho cột số: ? ** Tuyệt đối không thay `NULL` bằng số `0` cho các cột như mặt tiền hay số tầng, vì sẽ làm sai lệch hoàn toàn các phép tính trung bình (Average) trên Power BI. Việc để nguyên `NULL` giúp hệ thống tự động bỏ qua chúng khi tính toán.

### Vấn đề 3: Ngoại lai (Outliers) - Nhà siêu nhỏ
- **Tình trạng:** Phát hiện các căn nhà có diện tích cực kỳ phi lý (<= 5m2).
- **Giải pháp:** Dùng lệnh `CASE WHEN` để tạo thêm một cột cờ (flag) `area_suspect` (kiểu boolean true/false) thay vì dùng lệnh `DELETE` để xóa vật lý.
- **Lý do (Tư duy phân tích):** 
  - **Thiếu bằng chứng tuyệt đối:** Diện tích 5m2 có thể là do người dùng gõ nhầm (typo 50m2 thành 5m2), cố tình điền bừa, hoặc thực sự là một ki-ốt siêu nhỏ. Khác với lỗi trùng lặp dữ liệu, trường hợp này chưa đủ "bằng chứng thép" để loại bỏ hoàn toàn.
  - **Bảo toàn dữ liệu (Data Integrity):** Việc "cắm cờ" giúp giữ nguyên bức tranh thực tế của thị trường (bao gồm cả những tin đăng nhiễu). 
  - **Trao quyền cho lớp BI (Business Intelligence):** Khi đưa dữ liệu lên Power BI, cột `area_suspect` sẽ đóng vai trò là một bộ lọc (Slicer). Người xem báo cáo có thể chủ động click để giữ hoặc loại bỏ các điểm dị thường này khỏi biểu đồ (Scatter Plot) theo nhu cầu phân tích, thay vì bị Data Analyst tự ý xóa mất ngay từ tầng Database.

### Vấn đề 4: Tin đăng rác/Trùng lặp (Spam/Deduplication)
- **Tình trạng:** Phát hiện 2.699 dòng tin đăng bị copy-paste, giống hệt nhau về cả 3 tiêu chí trọng điểm: Địa chỉ (`address`), Giá (`price_billion_vnd`), và Diện tích (`area_sqm`).
- **Giải pháp:** Dùng CTE kết hợp với Window Function `ROW_NUMBER() OVER(PARTITION BY...)` để đánh số thứ tự trong từng nhóm trùng lặp, sau đó xóa (`DELETE`) các bản sao (`row_num > 1`) và chỉ giữ lại 1 bản ghi gốc.
- **Lý do (Tư duy phân tích):** Trái ngược với Vấn đề 3, việc 3 trường thông tin cốt lõi trùng khớp hoàn toàn là bằng chứng chắc chắn của hành vi "spam tin đăng" từ môi giới. Xóa thẳng tay (Hard Delete) ở bước này là bắt buộc để đảm bảo tính chính xác của các chỉ số tổng hợp (đặc biệt là giá trung bình theo khu vực).
- **Verify:** Đã viết một Python script độc lập để mô phỏng lại toàn bộ pipeline làm sạch (loại address rác ➔ parse city/district ➔ chuẩn hoá prefix ➔ flag area_suspect ➔ dedup). Kết quả xác nhận số lượng 2.699 dòng bị xóa khớp 100% với logic SQ
