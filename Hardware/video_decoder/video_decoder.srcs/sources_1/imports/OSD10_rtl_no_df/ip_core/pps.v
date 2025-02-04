// 解析H.264/AVC视频编码标准中的图像参数集（Picture Parameter Set，简称PPS）,PPS是H.264编码视频流中的一个重要组成部分，包含了编码图像所需的一系列参数

// 主要功能
// 状态机：通过pps_state状态变量管理PPS解析的各个阶段。每个状态对应于PPS参数集中的一个特定字段的解析。
// 参数解析：在每个状态，模块会读取输入比特流中的相应部分，使用指数哥伦布编码解析出参数值，并将这些值赋给对应的输出端口。
// 控制流：根据输入的使能信号和状态机的当前状态，模块决定下一步操作。这可能涉及更新状态、读取并解析新的参数，或在完成所有必要解析后重置状态机。
// 时序逻辑：使用时钟信号和复位信号控制模块的操作，确保参数的同步更新。
// 解析的参数
// 模块解析的参数包括但不限于：

// 图像参数集ID（pic_parameter_set_id）。
// 序列参数集ID（seq_parameter_set_id）。
// 熵编码模式标志（entropy_coding_mode_flag）。
// 图片顺序存在标志（pic_order_present_flag）。
// 参考帧索引（num_ref_idx_l0_active_minus1 和 num_ref_idx_l1_active_minus1）。
// 加权预测标志（weighted_pred_flag）和加权双向预测标识（weighted_bipred_idc）。
// 初始量化参数（pic_init_qp_minus26, pic_init_qs_minus26, chroma_qp_index_offset）。
// 去块滤波控制标志（deblocking_filter_control_present_flag）、限制帧内预测标志（constrained_intra_pred_flag）和冗余图片计数存在标志（redundant_pic_cnt_present_flag）

`include "defines.v"

module pps
(
 clk,
 rst_n,
 ena,
 rbsp_in,
 exp_golomb_decoding_output_in,
 exp_golomb_decoding_len_in,
 exp_golomb_decoding_output_se_in,
  
 pic_parameter_set_id,
 seq_parameter_set_id,
 entropy_coding_mode_flag, // 0 : CAVLC, 1 : CABAC
 pic_order_present_flag,
 num_slice_groups_minus1,
 num_ref_idx_l0_active_minus1,
 num_ref_idx_l1_active_minus1,
 weighted_pred_flag,
 weighted_bipred_idc,
 pic_init_qp_minus26,
 pic_init_qs_minus26,
 chroma_qp_index_offset,
 deblocking_filter_control_present_flag,
 constrained_intra_pred_flag,
 redundant_pic_cnt_present_flag,
 pps_state,
 forward_len_out
);

input clk;
input rst_n;
input ena; 
input[23:21] rbsp_in; // from rbsp_buffer output 
input[7:0] exp_golomb_decoding_output_in;
input[4:0] exp_golomb_decoding_len_in;
input[7:0] exp_golomb_decoding_output_se_in;
wire signed[7:0] exp_golomb_decoding_output_se_in;

output[7:0] pic_parameter_set_id;
output[4:0] seq_parameter_set_id;
output entropy_coding_mode_flag;
output pic_order_present_flag;
output[2:0] num_slice_groups_minus1;
output[2:0] num_ref_idx_l0_active_minus1;
output[2:0] num_ref_idx_l1_active_minus1;
output weighted_pred_flag;
output[1:0] weighted_bipred_idc;
output[5:0] pic_init_qp_minus26;
output[5:0] pic_init_qs_minus26;
output[4:0] chroma_qp_index_offset;
output deblocking_filter_control_present_flag;
output constrained_intra_pred_flag;
output redundant_pic_cnt_present_flag;
output[3:0] pps_state;
output[4:0] forward_len_out; // indicate how many bits consumed, ask rbsp_buffer to read from read_nalu

reg [7:0] pic_parameter_set_id;
reg [4:0] seq_parameter_set_id;
reg  entropy_coding_mode_flag;
reg  pic_order_present_flag;
reg [2:0] num_slice_groups_minus1;
reg [2:0] num_ref_idx_l0_active_minus1;
reg [2:0] num_ref_idx_l1_active_minus1;
reg  weighted_pred_flag;
reg [1:0] weighted_bipred_idc;
reg signed[5:0] pic_init_qp_minus26;
reg signed[5:0] pic_init_qs_minus26;
reg signed[4:0] chroma_qp_index_offset;
reg  deblocking_filter_control_present_flag;
reg  constrained_intra_pred_flag;
reg  redundant_pic_cnt_present_flag;
reg [3:0] pps_state;

reg[4:0] forward_len_out;


//       ______       ______       _____         
//      |      |     |      |     |     |
// -----        -----        -----       -----
//      1            2            3
// @1 pps_state = 1->2
// @1.1  read ue decode ue and len
// @2 rbsp_in move forward
// @3 pps_state 2->3  seq_parameter_set_id<=ue  
//  race condition, rbsp_in move forward and pic_parameter_set_id<=ue, if rbsp_in move first, then ue changes, 

// pps_state <= 4'b0010 3210:0010
// width mismatch assign, pps_state <= 5'b10101, high bits are ignored, [3-2-1-0]=[0-1-0-1]  

always @(pps_state or exp_golomb_decoding_len_in)
    case (pps_state)
        `rst_pic_parameter_set                                 : forward_len_out <= 0;
        `pic_parameter_set_id_pps_s                            : forward_len_out <= exp_golomb_decoding_len_in;
        `seq_parameter_set_id_pps_s                            : forward_len_out <= exp_golomb_decoding_len_in;	
        `entropy_coding_mode_flag_2_pic_order_present_flag     : forward_len_out <= 2;
        `num_slice_groups_minus1_s                             : forward_len_out <= exp_golomb_decoding_len_in;
        `num_ref_idx_l0_active_minus1_pps_s                    : forward_len_out <= exp_golomb_decoding_len_in;
        `num_ref_idx_l1_active_minus1_pps_s                    : forward_len_out <= exp_golomb_decoding_len_in;
        `weighted_pred_flag_2_weighted_bipred_idc              : forward_len_out <= 3;
        `pic_init_qp_minus26_s                                 : forward_len_out <= exp_golomb_decoding_len_in;
        `pic_init_qs_minus26_s                                 : forward_len_out <= exp_golomb_decoding_len_in;
        `chroma_qp_index_offset_s                              : forward_len_out <= exp_golomb_decoding_len_in;
        `deblocking_constrained_redundant                      : forward_len_out <= 3;
        `rbsp_trailing_bits_pps                                : forward_len_out <= -1;
        default : forward_len_out <= 0;
    endcase

always @ (posedge clk or negedge rst_n)
    if (rst_n == 0)
    	begin
    		pic_parameter_set_id                   <= 0;
    		seq_parameter_set_id                   <= 0;
    		entropy_coding_mode_flag               <= 0;
    		pic_order_present_flag                 <= 0;
    		num_slice_groups_minus1                <= 0;
    		num_ref_idx_l0_active_minus1           <= 0;
    		num_ref_idx_l1_active_minus1           <= 0;
    		weighted_pred_flag                     <= 0;
    		weighted_bipred_idc                    <= 0;
    		pic_init_qp_minus26                    <= 0;
    		pic_init_qs_minus26                    <= 0;
    		chroma_qp_index_offset                 <= 0;
    		deblocking_filter_control_present_flag <= 0;
    		constrained_intra_pred_flag            <= 0;
    		redundant_pic_cnt_present_flag         <= 0;
    		pps_state                              <= 0;
    	end
    else
        begin
            if(ena)
                case (pps_state)
                    `rst_pic_parameter_set:	
                        begin 
                            
                            pps_state <= `pic_parameter_set_id_pps_s;
                        end
                    `pic_parameter_set_id_pps_s:	
                        begin 
                            pic_parameter_set_id <= exp_golomb_decoding_output_in; 
                            
                            pps_state <= `seq_parameter_set_id_pps_s;
                        end
                    `seq_parameter_set_id_pps_s:    
                        begin 
                            seq_parameter_set_id <= exp_golomb_decoding_output_in; 
                            
                            pps_state <= `entropy_coding_mode_flag_2_pic_order_present_flag;
                        end
                    `entropy_coding_mode_flag_2_pic_order_present_flag:
                        begin 
                            entropy_coding_mode_flag <= rbsp_in[23];
                            pic_order_present_flag <= rbsp_in[22];
                            
                            pps_state <= `num_slice_groups_minus1_s;
                        end
                    `num_slice_groups_minus1_s:
                        begin 
                            num_slice_groups_minus1 <= exp_golomb_decoding_output_in; 
                            
                            pps_state <= `num_ref_idx_l0_active_minus1_pps_s;
                        end
                    `num_ref_idx_l0_active_minus1_pps_s:
                        begin 
                            num_ref_idx_l0_active_minus1 <= exp_golomb_decoding_output_in; 
                            
                            pps_state <= `num_ref_idx_l1_active_minus1_pps_s;
                        end
                    `num_ref_idx_l1_active_minus1_pps_s:
                        begin 
                            num_ref_idx_l1_active_minus1 <= exp_golomb_decoding_output_in; 
    
                            pps_state <= `weighted_pred_flag_2_weighted_bipred_idc;
                        end
                    `weighted_pred_flag_2_weighted_bipred_idc:
                        begin 
                            weighted_pred_flag <= rbsp_in[23]; 
                            weighted_bipred_idc <= rbsp_in[22:21];
                            
                            pps_state <= `pic_init_qp_minus26_s;
                        end
                    `pic_init_qp_minus26_s:
                        begin 
                            pic_init_qp_minus26 <= exp_golomb_decoding_output_se_in; 
                            
                            pps_state <= `pic_init_qs_minus26_s;
                        end
                    `pic_init_qs_minus26_s:
                        begin 
                            pic_init_qs_minus26 <= exp_golomb_decoding_output_se_in; 
                            
                            pps_state <= `chroma_qp_index_offset_s;
                        end
                    `chroma_qp_index_offset_s:
                        begin 
                            chroma_qp_index_offset <= exp_golomb_decoding_output_se_in; 
                            
                            pps_state <= `deblocking_constrained_redundant;
                        end
                    `deblocking_constrained_redundant:
                        begin 
                            deblocking_filter_control_present_flag <= rbsp_in[23];
                            constrained_intra_pred_flag <= rbsp_in[22];
                            redundant_pic_cnt_present_flag <= rbsp_in[21];
                            pps_state <= `rbsp_trailing_bits_pps;  

                        end
                    `rbsp_trailing_bits_pps:
                        pps_state <= `pps_end;
                    default: pps_state <= `rst_pic_parameter_set;            
                endcase        
        end    
    
endmodule
